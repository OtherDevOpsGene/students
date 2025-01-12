# IAM role for Lambda functions
resource "aws_iam_role" "lambda_role" {
  name = "students_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for CloudWatch Logs
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM policy for DynamoDB access
resource "aws_iam_role_policy" "dynamodb_access" {
  name = "students_dynamodb_access"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = aws_dynamodb_table.students.arn
      }
    ]
  })
}

# ZIP files for Lambda functions
data "archive_file" "collector_zip" {
  type        = "zip"
  source_dir  = "${path.module}/email-collector"
  output_path = "${path.module}/email-collector.zip"
}

data "archive_file" "lookup_zip" {
  type        = "zip"
  source_dir  = "${path.module}/email-lookup"
  output_path = "${path.module}/email-lookup.zip"
}

# Email Collector Lambda
resource "aws_lambda_function" "collector" {
  filename         = data.archive_file.collector_zip.output_path
  function_name    = "email-collector"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.collector_zip.output_base64sha256
  runtime          = "nodejs18.x"

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.students.name
    }
  }
}

# Email Lookup Lambda
resource "aws_lambda_function" "lookup" {
  filename         = data.archive_file.lookup_zip.output_path
  function_name    = "email-lookup"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.lookup_zip.output_base64sha256
  runtime          = "nodejs18.x"

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.students.name
    }
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "collector_logs" {
  name              = "/aws/lambda/${aws_lambda_function.collector.function_name}"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "lookup_logs" {
  name              = "/aws/lambda/${aws_lambda_function.lookup.function_name}"
  retention_in_days = 7
}

# Outputs
output "collector_function_name" {
  value = aws_lambda_function.collector.function_name
}

output "lookup_function_name" {
  value = aws_lambda_function.lookup.function_name
}

output "collector_function_arn" {
  value = aws_lambda_function.collector.arn
}

output "lookup_function_arn" {
  value = aws_lambda_function.lookup.arn
}
