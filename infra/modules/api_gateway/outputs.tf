output "rest_api_id" {
  description = "REST API ID."
  value       = aws_api_gateway_rest_api.this.id
}

output "stage_name" {
  description = "Stage name."
  value       = aws_api_gateway_stage.this.stage_name
}

output "stage_arn" {
  description = "Stage ARN."
  value       = aws_api_gateway_stage.this.arn
}

output "invoke_url" {
  description = "Base URL of the API."
  value       = aws_api_gateway_stage.this.invoke_url
}
