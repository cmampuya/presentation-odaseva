output "state_bucket_name" {
  description = "Name of the Terraform state bucket."
  value       = aws_s3_bucket.state.id
}

output "backend_hcl" {
  description = "Partial backend configuration for the main stack (written to infra/backend.hcl)."
  value       = <<-EOT
    bucket       = "${aws_s3_bucket.state.id}"
    key          = "${var.state_key}"
    region       = "${var.aws_region}"
    encrypt      = true
    use_lockfile = true
  EOT
}
