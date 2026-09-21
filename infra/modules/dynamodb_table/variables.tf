variable "table_name" {
  description = "DynamoDB table name."
  type        = string
}

variable "specialty_index_name" {
  description = "Name of the GSI used to list candidates by specialty."
  type        = string
  default     = "specialty-index"
}

variable "deletion_protection_enabled" {
  description = "Prevent accidental table deletion. Must be false to allow terraform destroy."
  type        = bool
  default     = true
}

variable "point_in_time_recovery_enabled" {
  description = "Enable continuous backups (35-day point-in-time recovery)."
  type        = bool
  default     = true
}
