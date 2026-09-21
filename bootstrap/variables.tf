variable "aws_region" {
  description = "AWS region hosting the Terraform state bucket."
  type        = string
  default     = "eu-west-3"
}

variable "state_key" {
  description = "Object key of the main stack state file."
  type        = string
  default     = "candidate-api/dev/terraform.tfstate"
}
