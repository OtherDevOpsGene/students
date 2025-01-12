# DynamoDB Table
resource "aws_dynamodb_table" "students" {
  name         = "students"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "email"

  attribute {
    name = "email"
    type = "S"
  }
}
