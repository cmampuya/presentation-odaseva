# Machine-to-machine authentication with the OAuth2 Client Credentials flow.
# - A resource server exposes custom scopes (e.g. candidates-api/candidates.read).
# - Each app client is confidential (client secret) and only allowed the
#   client_credentials grant with an explicit list of scopes.
# - API Gateway validates the access token signature, expiry and scopes.

data "aws_region" "current" {}

resource "aws_cognito_user_pool" "this" {
  name                = var.name
  deletion_protection = var.deletion_protection_enabled ? "ACTIVE" : "INACTIVE"

  # No end users: the pool only issues machine tokens. Disable self sign-up.
  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  password_policy {
    minimum_length                   = 14
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 1
  }
}

resource "aws_cognito_user_pool_domain" "this" {
  domain       = var.domain_prefix
  user_pool_id = aws_cognito_user_pool.this.id
}

resource "aws_cognito_resource_server" "this" {
  identifier   = var.resource_server_identifier
  name         = var.resource_server_identifier
  user_pool_id = aws_cognito_user_pool.this.id

  dynamic "scope" {
    for_each = var.scopes

    content {
      scope_name        = scope.key
      scope_description = scope.value
    }
  }
}

locals {
  # Fully qualified scope names: "<resource-server>/<scope>"
  scope_ids = {
    for name in keys(var.scopes) : name => "${aws_cognito_resource_server.this.identifier}/${name}"
  }
}

# Single confidential app client, allowed to request every scope of the
# resource server. API Gateway still enforces the scope per method.
resource "aws_cognito_user_pool_client" "this" {
  name         = "${var.name}-${var.client_name}"
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret                      = true
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["client_credentials"]
  allowed_oauth_scopes                 = values(local.scope_ids)
  supported_identity_providers         = ["COGNITO"]
  explicit_auth_flows                  = ["ALLOW_REFRESH_TOKEN_AUTH"]

  access_token_validity  = var.access_token_validity_minutes
  id_token_validity      = 60
  refresh_token_validity = 1

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  enable_token_revocation       = true
  prevent_user_existence_errors = "ENABLED"
}
