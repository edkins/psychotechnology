terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  profile = "giles"
  region  = "us-east-1"
}

variable "stage" {
  type = string
}

resource "aws_dynamodb_table" "imag_table" {
  name         = "${var.stage}_imag"
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "id"
  ttl {
    enabled        = true
    attribute_name = "expiration"
  }

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_iam_role" "api_lambda_role" {
  name = "${var.stage}_api_lambda"

  assume_role_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "lambda.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy" "api_lambda_policy" {
  name = "api_lambda_policy"
  role = aws_iam_role.api_lambda_role.id

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ],
        "Effect": "Allow",
        "Resource": "${aws_dynamodb_table.imag_table.arn}"
      }
    ]
  }
  EOF
}

resource "aws_lambda_function" "api_lambda" {
  function_name    = "${var.stage}_imag_api"
  filename         = "handler.zip"
  source_code_hash = filebase64sha256("handler.zip")
  role             = aws_iam_role.api_lambda_role.arn
  handler          = "handler.handler"
  runtime          = "python3.8"
}

resource "aws_apigatewayv2_api" "apig" {
  name          = "${var.stage}_imag_http"
  protocol_type = "HTTP"
}

resource "aws_lambda_permission" "lambda_permission" {
  statement_id  = "AllowMyPIInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_lambda.arn
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.apig.execution_arn}/*/*/*"
}

resource "aws_apigatewayv2_integration" "apig_integ" {
  api_id                    = aws_apigatewayv2_api.apig.id
  integration_type          = "AWS_PROXY"
  connection_type           = "INTERNET"
  integration_method        = "POST"
  integration_uri           = aws_lambda_function.api_lambda.invoke_arn
  passthrough_behavior      = "WHEN_NO_MATCH"
  payload_format_version    = "2.0"
}

resource "aws_apigatewayv2_route" "apig_route_api_get" {
  api_id    = aws_apigatewayv2_api.apig.id
  route_key = "GET /api/{path+}"
  target    = "integrations/${aws_apigatewayv2_integration.apig_integ.id}"
}

resource "aws_apigatewayv2_stage" "apig_stage" {
  api_id = aws_apigatewayv2_api.apig.id
  name = var.stage
  auto_deploy = true
}

