# Single execution role of the API function: exactly the actions the three
# routes need, on the exact resources they use. Data at rest is encrypted with
# AWS managed encryption (SSE-S3, DynamoDB default encryption), which needs no
# extra permission.

data "aws_iam_policy_document" "lambda" {
  # POST: allocate the next ID (atomic counter) and store the candidate.
  # GET by ID: read the candidate.
  statement {
    sid = "CandidatesTable"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
    ]
    resources = [module.candidates_table.table_arn]
  }

  # GET by specialty: query the index only.
  statement {
    sid       = "SpecialtyIndex"
    actions   = ["dynamodb:Query"]
    resources = ["${module.candidates_table.table_arn}/index/${module.candidates_table.specialty_index_name}"]
  }

  # POST: upload the resume, and delete that exact version if the DynamoDB
  # write fails. GET: the presigned URL is signed with the function
  # credentials, so the function must be allowed to read the object.
  statement {
    sid = "ResumeObjects"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObjectVersion",
    ]
    resources = ["${module.resume_bucket.bucket_arn}/*"]
  }
}
