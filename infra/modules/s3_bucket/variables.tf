variable "bucket_name" {
  description = "Globally unique bucket name."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name must be a valid S3 bucket name (3-63 lowercase characters)."
  }
}

variable "force_destroy" {
  description = "Delete all object versions on destroy. Keep true only for ephemeral environments."
  type        = bool
  default     = false
}

variable "noncurrent_version_expiration_days" {
  description = "Days before noncurrent object versions are permanently deleted."
  type        = number
  default     = 30
}
