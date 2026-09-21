# -----------------------------------------------------------------------------
# General
# -----------------------------------------------------------------------------
variable "project_name" {
  description = "Project name, used as prefix for every resource."
  type        = string
  default     = "candidate-api"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.project_name))
    error_message = "project_name must be 3-21 lowercase characters (letters, digits, hyphens)."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of dev, staging, prod."
  }
}

variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "eu-west-3"
}

variable "owner" {
  description = "Owner tag value."
  type        = string
  default     = "platform-team"
}

variable "tags" {
  description = "Additional tags applied to every resource."
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Lifecycle (demo friendly defaults: everything can be destroyed)
# -----------------------------------------------------------------------------
variable "deletion_protection_enabled" {
  description = "Enable deletion protection on DynamoDB and Cognito. Must be false to run terraform destroy."
  type        = bool
  default     = false
}

variable "force_destroy_bucket" {
  description = "Allow terraform destroy to delete a non-empty resume bucket."
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# API behaviour
# -----------------------------------------------------------------------------
variable "api_stage_name" {
  description = "API Gateway stage name."
  type        = string
  default     = "v1"
}

variable "presigned_url_ttl_seconds" {
  description = "Lifetime of resume download URLs."
  type        = number
  default     = 300

  validation {
    condition     = var.presigned_url_ttl_seconds >= 60 && var.presigned_url_ttl_seconds <= 3600
    error_message = "presigned_url_ttl_seconds must be between 60 and 3600."
  }
}

variable "max_resume_size_bytes" {
  description = "Maximum resume size. Bounded by the 6 MB Lambda payload limit after base64 encoding."
  type        = number
  default     = 4194304

  validation {
    condition     = var.max_resume_size_bytes > 0 && var.max_resume_size_bytes <= 4400000
    error_message = "max_resume_size_bytes must be between 1 and 4400000 (Lambda synchronous payload limit)."
  }
}

variable "api_throttling_rate_limit" {
  description = "Stage steady-state rate limit (requests per second)."
  type        = number
  default     = 50
}

variable "api_throttling_burst_limit" {
  description = "Stage burst limit."
  type        = number
  default     = 100
}

variable "access_token_validity_minutes" {
  description = "OAuth2 access token lifetime."
  type        = number
  default     = 60
}

# -----------------------------------------------------------------------------
# Compute
# -----------------------------------------------------------------------------
variable "lambda_memory_size" {
  description = "Lambda memory in MB."
  type        = number
  default     = 512
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds."
  type        = number
  default     = 15
}

variable "lambda_reserved_concurrency" {
  description = "Reserved concurrency per function (-1 = unreserved)."
  type        = number
  default     = -1
}

variable "log_level" {
  description = "Application log level."
  type        = string
  default     = "INFO"
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention."
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a value supported by CloudWatch Logs."
  }
}
