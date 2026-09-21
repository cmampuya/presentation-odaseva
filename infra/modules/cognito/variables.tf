variable "name" {
  description = "Name of the user pool (also used as client name prefix)."
  type        = string
}

variable "domain_prefix" {
  description = "Cognito hosted domain prefix. Must be unique in the region and must not contain 'aws', 'amazon' or 'cognito'."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$", var.domain_prefix)) && !can(regex("aws|amazon|cognito", var.domain_prefix))
    error_message = "domain_prefix must be lowercase alphanumeric/hyphens and must not contain 'aws', 'amazon' or 'cognito'."
  }
}

variable "resource_server_identifier" {
  description = "Identifier of the OAuth2 resource server (prefix of every scope)."
  type        = string
}

variable "scopes" {
  description = "Map of scope name => description."
  type        = map(string)

  validation {
    condition     = length(var.scopes) > 0
    error_message = "At least one scope is required for the client credentials flow."
  }
}

variable "client_name" {
  description = "Name suffix of the OAuth2 app client (client credentials)."
  type        = string
  default     = "client"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.client_name))
    error_message = "client_name must be 2-31 lowercase characters (letters, digits, hyphens)."
  }
}

variable "access_token_validity_minutes" {
  description = "Access token lifetime in minutes (5-1440)."
  type        = number
  default     = 60

  validation {
    condition     = var.access_token_validity_minutes >= 5 && var.access_token_validity_minutes <= 1440
    error_message = "access_token_validity_minutes must be between 5 and 1440."
  }
}

variable "deletion_protection_enabled" {
  description = "Prevent accidental deletion of the user pool."
  type        = bool
  default     = true
}
