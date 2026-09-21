output "user_pool_id" {
  description = "User pool ID."
  value       = aws_cognito_user_pool.this.id
}

output "user_pool_arn" {
  description = "User pool ARN."
  value       = aws_cognito_user_pool.this.arn
}

output "token_endpoint" {
  description = "OAuth2 token endpoint."
  value       = "https://${aws_cognito_user_pool_domain.this.domain}.auth.${data.aws_region.current.region}.amazoncognito.com/oauth2/token"
}

output "scope_ids" {
  description = "Map of short scope name => fully qualified scope."
  value       = local.scope_ids
}

output "client_id" {
  description = "OAuth2 client ID."
  value       = aws_cognito_user_pool_client.this.id
}

output "client_secret" {
  description = "OAuth2 client secret."
  value       = aws_cognito_user_pool_client.this.client_secret
  sensitive   = true
}

output "client_scopes" {
  description = "Fully qualified scopes the client can request."
  value       = sort(tolist(aws_cognito_user_pool_client.this.allowed_oauth_scopes))
}
