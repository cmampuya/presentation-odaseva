# -----------------------------------------------------------------------------
# Data stores
# -----------------------------------------------------------------------------
module "resume_bucket" {
  source = "./modules/s3_bucket"

  bucket_name   = "${local.name_prefix}-resumes-${local.region}-${local.suffix}"
  force_destroy = var.force_destroy_bucket
}

module "candidates_table" {
  source = "./modules/dynamodb_table"

  table_name                  = "${local.name_prefix}-candidates"
  deletion_protection_enabled = var.deletion_protection_enabled
}

# -----------------------------------------------------------------------------
# Identity (OAuth2 client credentials)
# -----------------------------------------------------------------------------
module "cognito" {
  source = "./modules/cognito"

  name                          = local.name_prefix
  domain_prefix                 = "${local.name_prefix}-${local.suffix}"
  resource_server_identifier    = local.resource_server_identifier
  scopes                        = local.oauth_scopes
  access_token_validity_minutes = var.access_token_validity_minutes
  deletion_protection_enabled   = var.deletion_protection_enabled
}

# -----------------------------------------------------------------------------
# Compute: one function serves the three routes
# -----------------------------------------------------------------------------
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../app/src"
  output_path = "${path.module}/.build/lambda.zip"
  excludes    = ["__pycache__"]
}

module "lambda" {
  source = "./modules/lambda_function"

  function_name = "${local.name_prefix}-api"
  description   = "Candidate API - POST /candidates, GET /candidates/{candidateId}, GET /candidates?specialty="
  handler       = "handlers.handler"
  package_path  = data.archive_file.lambda.output_path
  package_hash  = data.archive_file.lambda.output_base64sha256
  policy_json   = data.aws_iam_policy_document.lambda.json
  environment_variables = {
    TABLE_NAME                = module.candidates_table.table_name
    SPECIALTY_INDEX_NAME      = module.candidates_table.specialty_index_name
    BUCKET_NAME               = module.resume_bucket.bucket_name
    PRESIGNED_URL_TTL_SECONDS = tostring(var.presigned_url_ttl_seconds)
    MAX_RESUME_SIZE_BYTES     = tostring(var.max_resume_size_bytes)
  }
  memory_size          = var.lambda_memory_size
  timeout              = var.lambda_timeout
  reserved_concurrency = var.lambda_reserved_concurrency
  log_level            = var.log_level
  log_retention_days   = var.log_retention_days
}

# -----------------------------------------------------------------------------
# API
# -----------------------------------------------------------------------------
module "api" {
  source = "./modules/api_gateway"

  name                   = local.name_prefix
  description            = "Candidate management API"
  stage_name             = var.api_stage_name
  cognito_user_pool_arn  = module.cognito.user_pool_arn
  throttling_rate_limit  = var.api_throttling_rate_limit
  throttling_burst_limit = var.api_throttling_burst_limit

  routes = {
    create_candidate = {
      resource             = "candidates"
      http_method          = "POST"
      scopes               = [module.cognito.scope_ids["candidates.write"]]
      lambda_function_name = module.lambda.function_name
      lambda_invoke_arn    = module.lambda.invoke_arn
    }
    list_candidates = {
      resource             = "candidates"
      http_method          = "GET"
      scopes               = [module.cognito.scope_ids["candidates.read"]]
      lambda_function_name = module.lambda.function_name
      lambda_invoke_arn    = module.lambda.invoke_arn
      request_parameters = {
        "method.request.querystring.specialty" = true
      }
    }
    get_candidate = {
      resource             = "candidate"
      http_method          = "GET"
      scopes               = [module.cognito.scope_ids["candidates.read"]]
      lambda_function_name = module.lambda.function_name
      lambda_invoke_arn    = module.lambda.invoke_arn
      request_parameters = {
        "method.request.path.candidateId" = true
      }
    }
  }
}
