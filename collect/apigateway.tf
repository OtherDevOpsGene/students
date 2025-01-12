# API Gateway
resource "aws_api_gateway_rest_api" "email_api" {
  name        = "email-service-api"
  description = "API Gateway for Email Service"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# Resources and methods for email collector (POST /subscribe)
resource "aws_api_gateway_resource" "subscribe" {
  rest_api_id = aws_api_gateway_rest_api.email_api.id
  parent_id   = aws_api_gateway_rest_api.email_api.root_resource_id
  path_part   = "subscribe"
}

resource "aws_api_gateway_method" "subscribe_post" {
  rest_api_id   = aws_api_gateway_rest_api.email_api.id
  resource_id   = aws_api_gateway_resource.subscribe.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "subscribe_lambda" {
  rest_api_id = aws_api_gateway_rest_api.email_api.id
  resource_id = aws_api_gateway_resource.subscribe.id
  http_method = aws_api_gateway_method.subscribe_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.collector.invoke_arn
}

# Resources and methods for email lookup (GET /lookup)
resource "aws_api_gateway_resource" "lookup" {
  rest_api_id = aws_api_gateway_rest_api.email_api.id
  parent_id   = aws_api_gateway_rest_api.email_api.root_resource_id
  path_part   = "lookup"
}

resource "aws_api_gateway_method" "lookup_get" {
  rest_api_id   = aws_api_gateway_rest_api.email_api.id
  resource_id   = aws_api_gateway_resource.lookup.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lookup_lambda" {
  rest_api_id = aws_api_gateway_rest_api.email_api.id
  resource_id = aws_api_gateway_resource.lookup.id
  http_method = aws_api_gateway_method.lookup_get.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lookup.invoke_arn
}

# Enable CORS
resource "aws_api_gateway_method" "subscribe_options" {
  rest_api_id   = aws_api_gateway_rest_api.email_api.id
  resource_id   = aws_api_gateway_resource.subscribe.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "lookup_options" {
  rest_api_id   = aws_api_gateway_rest_api.email_api.id
  resource_id   = aws_api_gateway_resource.lookup.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "options_200" {
  rest_api_id = aws_api_gateway_rest_api.email_api.id
  resource_id = aws_api_gateway_resource.subscribe.id
  http_method = aws_api_gateway_method.subscribe_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "api" {
  rest_api_id = aws_api_gateway_rest_api.email_api.id

  depends_on = [
    aws_api_gateway_integration.subscribe_lambda,
    aws_api_gateway_integration.lookup_lambda
  ]
}

# API Gateway Stage
resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.api.id
  rest_api_id   = aws_api_gateway_rest_api.email_api.id
  stage_name    = "prod"
}

# Lambda permissions for API Gateway
resource "aws_lambda_permission" "api_gw_collector" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.collector.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.email_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gw_lookup" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lookup.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.email_api.execution_arn}/*/*"
}

# Output the API Gateway URL
output "api_url" {
  value = aws_api_gateway_stage.prod.invoke_url
}