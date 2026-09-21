output "api_base_url" {
  description = "Base URL of the candidate API."
  value       = module.api.invoke_url
}

output "token_endpoint" {
  description = "Cognito OAuth2 token endpoint."
  value       = module.cognito.token_endpoint
}

output "client_id" {
  description = "OAuth2 client ID."
  value       = module.cognito.client_id
}

output "client_scopes" {
  description = "OAuth2 scopes the client can request (space-join them in the token request)."
  value       = module.cognito.client_scopes
}

output "client_secret" {
  description = "OAuth2 client secret (sensitive). Read with: terraform output -raw client_secret"
  value       = module.cognito.client_secret
  sensitive   = true
}

output "resume_bucket_name" {
  description = "S3 bucket storing resumes."
  value       = module.resume_bucket.bucket_name
}

output "candidates_table_name" {
  description = "DynamoDB table storing candidates."
  value       = module.candidates_table.table_name
}

output "lambda_function_name" {
  description = "Lambda function serving the API."
  value       = module.lambda.function_name
}
