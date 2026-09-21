variable "function_name" {
  description = "Lambda function name (also used as IAM role name)."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]{1,64}$", var.function_name))
    error_message = "function_name must be 1-64 characters: letters, digits, hyphens, underscores."
  }
}

variable "description" {
  description = "Function description."
  type        = string
  default     = ""
}

variable "handler" {
  description = "Function entry point (module.function)."
  type        = string
}

variable "runtime" {
  description = "Lambda runtime."
  type        = string
  default     = "python3.13"
}

variable "package_path" {
  description = "Path to the deployment package (.zip)."
  type        = string
}

variable "package_hash" {
  description = "Base64 SHA256 of the deployment package, triggers code updates."
  type        = string
}

variable "policy_json" {
  description = "IAM policy (JSON) granting the function access to its data stores."
  type        = string
}

variable "environment_variables" {
  description = "Environment variables (no secrets)."
  type        = map(string)
  default     = {}
}

variable "memory_size" {
  description = "Memory in MB (also scales CPU)."
  type        = number
  default     = 512
}

variable "timeout" {
  description = "Timeout in seconds. Must stay below the API Gateway integration timeout (29 s)."
  type        = number
  default     = 15

  validation {
    condition     = var.timeout >= 1 && var.timeout <= 28
    error_message = "timeout must be between 1 and 28 seconds for a synchronous API integration."
  }
}

variable "reserved_concurrency" {
  description = "Reserved concurrency. -1 means unreserved (use the account pool)."
  type        = number
  default     = -1
}

variable "log_level" {
  description = "Application log level."
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["TRACE", "DEBUG", "INFO", "WARN", "ERROR", "FATAL"], var.log_level)
    error_message = "log_level must be one of TRACE, DEBUG, INFO, WARN, ERROR, FATAL."
  }
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days."
  type        = number
  default     = 30
}
