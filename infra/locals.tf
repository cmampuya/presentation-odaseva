data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Short random suffix for globally unique names (S3 bucket, Cognito domain).
resource "random_id" "suffix" {
  byte_length = 3
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  account_id  = data.aws_caller_identity.current.account_id
  region      = data.aws_region.current.region
  suffix      = random_id.suffix.hex

  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      Owner       = var.owner
      ManagedBy   = "terraform"
      DataClass   = "confidential-pii"
    },
    var.tags,
  )

  # OAuth2 model: one resource server with two scopes and one client.
  # API Gateway requires candidates.write on POST and candidates.read on GET.
  resource_server_identifier = local.name_prefix
  oauth_scopes = {
    "candidates.read"  = "Read candidates and download resumes"
    "candidates.write" = "Create candidates and upload resumes"
  }
}
