###########################
#
# Header
#
###########################

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

data "aws_caller_identity" "current" {}

###########################
#
# DynamoDB
#
###########################

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

###########################
#
# S3
#
###########################

resource "aws_s3_bucket" "static" {
  bucket = "${data.aws_caller_identity.current.account_id}-${var.stage}-static"
}

resource "aws_s3_bucket_public_access_block" "static_block" {
  bucket                  = aws_s3_bucket.static.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_object" "index" {
  bucket = aws_s3_bucket.static.id
  key    = "index.html"
  source = "index.html"
  etag   = filemd5("index.html")
}

###########################
#
# IAM roles and policies
#
###########################


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
      },
      {
        "Action": [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Effect": "Allow",
        "Resource": "arn:aws:logs:*:*:log-group:/aws/lambda/${var.stage}_imag_api*"
      }
    ]
  }
  EOF
}

resource "aws_iam_role" "s3_lambda_role" {
  name = "${var.stage}_s3_lambda"

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

resource "aws_iam_role_policy" "s3_lambda_policy" {
  name = "s3_lambda_policy"
  role = aws_iam_role.s3_lambda_role.id

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "s3:GetObject"
        ],
        "Effect": "Allow",
        "Resource": "${aws_s3_bucket.static.arn}/*"
      },
      {
        "Action": [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Effect": "Allow",
        "Resource": "arn:aws:logs:*:*:log-group:/aws/lambda/${var.stage}_imag_s3*"
      }
    ]
  }
  EOF
}

###########################
#
# Lambdas
#
###########################

resource "aws_lambda_function" "api_lambda" {
  function_name    = "${var.stage}_imag_api"
  filename         = "handler.zip"
  source_code_hash = filebase64sha256("handler.zip")
  role             = aws_iam_role.api_lambda_role.arn
  handler          = "handler.handler"
  runtime          = "python3.8"
  environment {
    variables = {
      table = aws_dynamodb_table.imag_table.name
    }
  }
}

resource "aws_lambda_function" "s3_lambda" {
  function_name    = "${var.stage}_imag_s3"
  filename         = "handler.zip"
  source_code_hash = filebase64sha256("handler.zip")
  role             = aws_iam_role.s3_lambda_role.arn
  handler          = "s3.handler"
  runtime          = "python3.8"
  environment {
    variables = {
      bucket = aws_s3_bucket.static.id
    }
  }
}

###########################
#
# API Gateway + Lambda permissions
#
###########################

resource "aws_apigatewayv2_api" "apig" {
  name          = "${var.stage}_imag_http"
  protocol_type = "HTTP"
}

resource "aws_lambda_permission" "api_lambda_permission" {
  statement_id  = "AllowAPIInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_lambda.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.apig.execution_arn}/*/*/*"
}

resource "aws_lambda_permission" "s3_lambda_permission" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_lambda.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.apig.execution_arn}/*/*/*"
}

resource "aws_apigatewayv2_integration" "apig_api_integ" {
  api_id                 = aws_apigatewayv2_api.apig.id
  integration_type       = "AWS_PROXY"
  connection_type        = "INTERNET"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.api_lambda.invoke_arn
  passthrough_behavior   = "WHEN_NO_MATCH"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "apig_s3_integ" {
  api_id                 = aws_apigatewayv2_api.apig.id
  integration_type       = "AWS_PROXY"
  connection_type        = "INTERNET"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.s3_lambda.invoke_arn
  passthrough_behavior   = "WHEN_NO_MATCH"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "apig_route_api_get" {
  api_id    = aws_apigatewayv2_api.apig.id
  route_key = "GET /api/{path+}"
  target    = "integrations/${aws_apigatewayv2_integration.apig_api_integ.id}"
}

resource "aws_apigatewayv2_route" "apig_route_api_post" {
  api_id    = aws_apigatewayv2_api.apig.id
  route_key = "POST /api/{path+}"
  target    = "integrations/${aws_apigatewayv2_integration.apig_api_integ.id}"
}

resource "aws_apigatewayv2_route" "apig_route_root" {
  api_id    = aws_apigatewayv2_api.apig.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.apig_s3_integ.id}"
}

resource "aws_apigatewayv2_route" "apig_route_room" {
  api_id    = aws_apigatewayv2_api.apig.id
  route_key = "GET /room/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.apig_s3_integ.id}"
}

resource "aws_apigatewayv2_stage" "apig_stage" {
  api_id      = aws_apigatewayv2_api.apig.id
  name        = "$default"
  auto_deploy = true
  default_route_settings {
    throttling_burst_limit = 10
    throttling_rate_limit  = 1
  }
}

