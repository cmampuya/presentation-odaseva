# Candidate Management API on AWS (Terraform)

This repository contains a REST API to create, read and list job candidates and their resumes. It runs serverless on AWS and is fully deployed with Terraform.

- **Endpoints:** `POST /candidates`, `GET /candidates/{candidateId}`, `GET /candidates?specialty=`
- **Services:** the five requested ones: Cognito (OAuth2 client credentials), API Gateway (REST), Lambda (Python 3.13, arm64), DynamoDB and S3
- **Documentation:** full technical specification in [`docs/TECHNICAL_SPECIFICATION.md`](docs/TECHNICAL_SPECIFICATION.md)

## Quick start

```bash
export AWS_PROFILE=<profile> AWS_REGION=eu-west-3

make bootstrap   # once: remote state bucket + infra/backend.hcl
cp infra/terraform.tfvars.example infra/terraform.tfvars
make init
make apply       # deploy 42 resources (~2-3 min)
make seed        # load the 7 sample candidates
make demo        # end-to-end scenario with curl
```

To destroy and re-create the stack:

```bash
make destroy && make apply && make seed
```

Requirements: Terraform ≥ 1.10, AWS CLI v2, `curl`, `jq`, `make`. `make lint` also needs `tflint` and `checkov`.

## Repository layout

| Path | Content |
|---|---|
| `bootstrap/` | S3 bucket for the Terraform state (native S3 locking) |
| `infra/` | Main stack: module wiring, IAM policies, outputs |
| `infra/modules/` | `cognito`, `api_gateway`, `lambda_function`, `dynamodb_table`, `s3_bucket` |
| `app/src/` | Lambda code: one function, `handlers.handler` routes the three endpoints; standard library + boto3 only |
| `scripts/` | `get-token.sh`, `seed.sh`, `demo.sh` |
| `postman/` | Postman collection with OAuth2 client credentials |
| `samples/` | Demo resumes (pdf, docx, ppt) and an invalid file |

## Authentication in one call

```bash
cd infra
curl -s -X POST "$(terraform output -raw token_endpoint)" \
  -u "$(terraform output -raw client_id):$(terraform output -raw client_secret)" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "grant_type=client_credentials" \
  --data-urlencode "scope=$(terraform output -json client_scopes | jq -r 'join(" ")')" | jq
```

There is one OAuth2 client. It can request two scopes, which API Gateway checks on every method:

| Scope | Required by |
|---|---|
| `candidates.write` | `POST /candidates` |
| `candidates.read` | `GET /candidates/{candidateId}`, `GET /candidates?specialty=` |

A token requested with `candidates.read` only is refused on `POST` (see `make demo`).

## Production switches

Set the following in `terraform.tfvars` for any non-ephemeral environment:

```hcl
deletion_protection_enabled = true
force_destroy_bucket        = false
```
