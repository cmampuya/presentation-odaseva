# Lambda function with its own execution role, a pre-created CloudWatch log
# group with retention (removed on destroy) and JSON structured logs.

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  log_group_name = "/aws/lambda/${var.function_name}"
  log_group_arn  = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:${local.log_group_name}"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = var.function_name
  description        = "Execution role of the ${var.function_name} Lambda function"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "logging" {
  statement {
    sid       = "WriteOwnLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${local.log_group_arn}:*"]
  }
}

resource "aws_iam_role_policy" "logging" {
  name   = "logging"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.logging.json
}

resource "aws_iam_role_policy" "application" {
  name   = "application"
  role   = aws_iam_role.this.id
  policy = var.policy_json
}

resource "aws_cloudwatch_log_group" "this" {
  #checkov:skip=CKV_AWS_338:Retention is a variable (30 days in dev, raise for production)
  #checkov:skip=CKV_AWS_158:CloudWatch Logs default encryption - no personal data is logged
  name              = local.log_group_name
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "this" {
  #checkov:skip=CKV_AWS_50:X-Ray tracing is out of the requested scope (five services)
  #checkov:skip=CKV_AWS_116:Synchronous API invocations - a DLQ only applies to async events
  #checkov:skip=CKV_AWS_117:Uses only AWS public endpoints over TLS - a VPC adds NAT cost without reducing exposure
  #checkov:skip=CKV_AWS_173:Environment variables hold no secrets (resource names and limits only)
  #checkov:skip=CKV_AWS_272:Code signing requires a signing profile and CI/CD pipeline, out of the requested scope
  function_name                  = var.function_name
  description                    = var.description
  role                           = aws_iam_role.this.arn
  runtime                        = var.runtime
  architectures                  = ["arm64"]
  handler                        = var.handler
  filename                       = var.package_path
  source_code_hash               = var.package_hash
  memory_size                    = var.memory_size
  timeout                        = var.timeout
  reserved_concurrent_executions = var.reserved_concurrency

  environment {
    variables = var.environment_variables
  }

  logging_config {
    log_format            = "JSON"
    application_log_level = var.log_level
    system_log_level      = "WARN"
    log_group             = aws_cloudwatch_log_group.this.name
  }

  depends_on = [
    aws_iam_role_policy.logging,
    aws_iam_role_policy.application,
  ]
}
