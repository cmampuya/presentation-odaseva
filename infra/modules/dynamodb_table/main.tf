# Candidates table.
#   PK  candidateId (S)                  -> GET /candidates/{candidateId}
#   GSI specialty-index: specialty + candidateId -> GET /candidates?specialty=
# The ID sequence counter lives in the same table under a reserved key; it has
# no "specialty" attribute, so it never appears in the (sparse) GSI.
# Encryption at rest is always on: DynamoDB default encryption (AWS owned key).

resource "aws_dynamodb_table" "this" {
  #checkov:skip=CKV_AWS_119:Default DynamoDB encryption at rest by design - a customer managed KMS key is out of the requested scope
  name                        = var.table_name
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "candidateId"
  deletion_protection_enabled = var.deletion_protection_enabled

  attribute {
    name = "candidateId"
    type = "S"
  }

  attribute {
    name = "specialty"
    type = "S"
  }

  global_secondary_index {
    name               = var.specialty_index_name
    hash_key           = "specialty"
    range_key          = "candidateId"
    projection_type    = "INCLUDE"
    non_key_attributes = ["candidateFirstName", "candidateLastName", "candidateBirthDate"]
  }

  point_in_time_recovery {
    enabled = var.point_in_time_recovery_enabled
  }
}
