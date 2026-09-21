# Candidate API - common tasks
SHELL := /usr/bin/env bash
TF    := terraform -chdir=infra

.DEFAULT_GOAL := help
.PHONY: help bootstrap init fmt validate lint plan apply destroy redeploy outputs token seed demo

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

bootstrap: ## Create the remote state bucket (once) and write infra/backend.hcl
	terraform -chdir=bootstrap init
	terraform -chdir=bootstrap apply
	terraform -chdir=bootstrap output -raw backend_hcl > infra/backend.hcl

init: ## Initialise the main stack with the S3 backend
	$(TF) init -backend-config=backend.hcl

fmt: ## Format all Terraform files
	terraform fmt -recursive

validate: ## Check formatting and validate the configuration
	terraform fmt -recursive -check
	$(TF) validate

lint: ## Static analysis (requires tflint and checkov)
	cd infra && tflint --recursive
	checkov -d infra --quiet --compact

plan: ## Create an execution plan
	$(TF) plan -out=tfplan

apply: plan ## Apply the plan
	$(TF) apply tfplan

destroy: ## Destroy the whole stack
	$(TF) destroy -auto-approve

redeploy: destroy apply ## Demo: destroy then re-create everything

outputs: ## Show stack outputs
	$(TF) output

token: ## Print an access token (SCOPE=candidates.read to restrict it)
	@scripts/get-token.sh $(SCOPE)

seed: ## Load the 7 sample candidates of the exercise
	scripts/seed.sh

demo: ## Run the end-to-end API demo
	scripts/demo.sh
