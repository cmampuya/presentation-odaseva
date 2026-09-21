# Regional REST API:
#   POST /candidates                 (scope: write)
#   GET  /candidates?specialty=...   (scope: read)
#   GET  /candidates/{candidateId}   (scope: read)
# Every method is protected by a Cognito authorizer. Because authorization
# scopes are set, API Gateway expects an OAuth2 *access token* (client
# credentials) and rejects tokens missing the required scope (403).

# -----------------------------------------------------------------------------
# REST API and resources
# -----------------------------------------------------------------------------
resource "aws_api_gateway_rest_api" "this" {
  #checkov:skip=CKV_AWS_237:create_before_destroy is set on the deployment, which is what avoids downtime
  name        = var.name
  description = var.description

  # Resumes are sent as multipart/form-data: API Gateway must pass the raw body
  # to Lambda base64-encoded instead of trying to decode it as text.
  binary_media_types = local.binary_media_types

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "candidates" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "candidates"
}

resource "aws_api_gateway_resource" "candidate" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.candidates.id
  path_part   = "{candidateId}"
}

locals {
  resources = {
    candidates = {
      id   = aws_api_gateway_resource.candidates.id
      path = "/candidates"
    }
    candidate = {
      id   = aws_api_gateway_resource.candidate.id
      path = "/candidates/*"
    }
  }
}

# -----------------------------------------------------------------------------
# Authentication and request validation
# -----------------------------------------------------------------------------
resource "aws_api_gateway_authorizer" "cognito" {
  name            = "cognito-client-credentials"
  rest_api_id     = aws_api_gateway_rest_api.this.id
  type            = "COGNITO_USER_POOLS"
  provider_arns   = [var.cognito_user_pool_arn]
  identity_source = "method.request.header.Authorization"
}

resource "aws_api_gateway_request_validator" "parameters" {
  name                        = "validate-parameters"
  rest_api_id                 = aws_api_gateway_rest_api.this.id
  validate_request_parameters = true
  validate_request_body       = false
}

# -----------------------------------------------------------------------------
# Routes (method + Lambda proxy integration + invoke permission)
# -----------------------------------------------------------------------------
resource "aws_api_gateway_method" "this" {
  for_each = var.routes

  rest_api_id          = aws_api_gateway_rest_api.this.id
  resource_id          = local.resources[each.value.resource].id
  http_method          = each.value.http_method
  authorization        = "COGNITO_USER_POOLS"
  authorizer_id        = aws_api_gateway_authorizer.cognito.id
  authorization_scopes = each.value.scopes
  request_parameters   = each.value.request_parameters
  request_validator_id = length(each.value.request_parameters) > 0 ? aws_api_gateway_request_validator.parameters.id : null
}

resource "aws_api_gateway_integration" "this" {
  for_each = var.routes

  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_method.this[each.key].resource_id
  http_method             = aws_api_gateway_method.this[each.key].http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = each.value.lambda_invoke_arn
  timeout_milliseconds    = 29000
}

resource "aws_lambda_permission" "this" {
  for_each = var.routes

  statement_id  = "AllowApiGatewayInvoke-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  # Scoped to this API, this method and this path only.
  source_arn = "${aws_api_gateway_rest_api.this.execution_arn}/*/${each.value.http_method}${local.resources[each.value.resource].path}"
}

# -----------------------------------------------------------------------------
# Consistent JSON error bodies for errors raised by API Gateway itself
# -----------------------------------------------------------------------------
locals {
  binary_media_types = ["multipart/form-data"]

  gateway_response_types = [
    "DEFAULT_4XX",
    "DEFAULT_5XX",
    "UNAUTHORIZED",
    "ACCESS_DENIED",
    "BAD_REQUEST_PARAMETERS",
    "REQUEST_TOO_LARGE",
    "THROTTLED",
  ]
  gateway_response_templates = {
    "application/json" = "{\"message\":$context.error.messageString,\"requestId\":\"$context.requestId\"}"
  }
  gateway_response_parameters = {
    "gatewayresponse.header.Strict-Transport-Security" = "'max-age=31536000; includeSubDomains'"
    "gatewayresponse.header.X-Content-Type-Options"    = "'nosniff'"
  }
}

resource "aws_api_gateway_gateway_response" "this" {
  for_each = toset(local.gateway_response_types)

  rest_api_id         = aws_api_gateway_rest_api.this.id
  response_type       = each.value
  response_templates  = local.gateway_response_templates
  response_parameters = local.gateway_response_parameters
}

# -----------------------------------------------------------------------------
# Deployment and stage
# -----------------------------------------------------------------------------
resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  # Any change to the API definition creates a new deployment. The hash is
  # built from configuration inputs only (never from whole resources, whose
  # computed attributes can change during apply and make the provider fail
  # with "inconsistent final plan").
  triggers = {
    redeployment = sha1(jsonencode([
      local.binary_media_types,
      aws_api_gateway_resource.candidates.id,
      aws_api_gateway_resource.candidate.id,
      var.cognito_user_pool_arn,
      var.routes,
      local.gateway_response_types,
      local.gateway_response_templates,
      local.gateway_response_parameters,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.this,
    aws_api_gateway_gateway_response.this,
  ]
}

resource "aws_api_gateway_stage" "this" {
  #checkov:skip=CKV_AWS_120:No caching - responses contain personal data and short-lived presigned URLs
  #checkov:skip=CKV2_AWS_29:WAF is out of the requested scope - stage throttling and Cognito scopes protect the API
  #checkov:skip=CKV_AWS_73:X-Ray tracing is out of the requested scope (five services)
  #checkov:skip=CKV2_AWS_51:Clients authenticate with OAuth2 access tokens, not mTLS
  #checkov:skip=CKV2_AWS_4:Execution logging needs an account-level CloudWatch role, out of the requested scope
  #checkov:skip=CKV_AWS_76:API Gateway access logging is out of the requested scope - the Lambda function logs one audit line per request
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = var.stage_name
}

resource "aws_api_gateway_method_settings" "all" {
  #checkov:skip=CKV_AWS_225:No caching - responses contain personal data and short-lived presigned URLs
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled        = false
    logging_level          = "OFF"
    data_trace_enabled     = false # never log request/response bodies (PII)
    throttling_rate_limit  = var.throttling_rate_limit
    throttling_burst_limit = var.throttling_burst_limit
  }
}
