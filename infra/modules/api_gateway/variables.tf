variable "name" {
  description = "REST API name."
  type        = string
}

variable "description" {
  description = "REST API description."
  type        = string
  default     = ""
}

variable "stage_name" {
  description = "Deployment stage name."
  type        = string
  default     = "v1"
}

variable "cognito_user_pool_arn" {
  description = "ARN of the Cognito user pool issuing access tokens."
  type        = string
}

variable "routes" {
  description = <<-EOT
    Map of routes. resource is either "candidates" (/candidates) or
    "candidate" (/candidates/{candidateId}). scopes are fully qualified
    Cognito scopes required to call the route.
  EOT
  type = map(object({
    resource             = string
    http_method          = string
    scopes               = list(string)
    lambda_function_name = string
    lambda_invoke_arn    = string
    request_parameters   = optional(map(bool), {})
  }))

  validation {
    condition     = alltrue([for r in values(var.routes) : contains(["candidates", "candidate"], r.resource)])
    error_message = "routes[*].resource must be 'candidates' or 'candidate'."
  }

  validation {
    condition     = alltrue([for r in values(var.routes) : length(r.scopes) > 0])
    error_message = "Every route must require at least one OAuth2 scope."
  }
}

variable "throttling_rate_limit" {
  description = "Steady-state requests per second allowed on the stage."
  type        = number
  default     = 50
}

variable "throttling_burst_limit" {
  description = "Burst capacity of the stage."
  type        = number
  default     = 100
}
