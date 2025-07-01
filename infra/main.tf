terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "6.0.0"
    }
  }
}

locals {
  content_type_map = {
    "js" = "application/javascript"
    "html" = "text/html"
    "css" = "text/css"
  }
}

provider "aws" {
 region = "us-east-2"
}
 
resource "aws_s3_bucket" "resumes_bucket" {
    bucket = "infra-demo-bucket-resume-tk"
    
   
   website {
    index_document = "index.html"
   }

   tags = {
    Name = "Resume bucket demo"

   }
 }

resource "aws_s3_bucket_public_access_block" "website_bucket_access" {
  bucket = "infra-demo-bucket-resume-tk"

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "website_bucket_policy" {
  bucket = aws_s3_bucket.resumes_bucket.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Allow s3:GetObject for everyone",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${aws_s3_bucket.resumes_bucket.bucket}/*"
    }
  ]
}
EOF
}

resource "aws_s3_bucket_object" "website_files" {
  for_each = fileset("${path.root}/../frontend", "**/*")

  bucket = "infra-demo-bucket-resume-tk"
  key    = each.value
  source = "${path.root}/../frontend/${each.value}"
  content_type = lookup(
    {
      html = "text/html"
      css  = "text/css"
      js   = "application/javascript"
      png  = "image/png"
      jpg  = "image/jpeg"
      jpeg = "image/jpeg"
      svg  = "image/svg+xml"
      ico  = "image/x-icon"
    },
    lower(regex("\\.([^.]+)$", each.value)[0]),
    "application/octet-stream"
  )
  depends_on = [aws_s3_bucket_policy.website_bucket_policy]
}


resource "aws_dynamodb_table" "site_visits" {
  name         = "site_visits"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "visit_id"

  attribute {
    name = "visit_id"
    type = "S"
  }
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_policy"
  role = aws_iam_role.lambda_exec.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:PutItem"
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.site_visits.arn
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_lambda_function" "visit_logger" {
  function_name = "visit_logger"
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  role          = aws_iam_role.lambda_exec.arn
  filename      = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.site_visits.name
    }
  }
}

resource "aws_apigatewayv2_api" "http_api" {
  name          = "visit_api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["http://infra-demo-bucket-resume-tk.s3-website.us-east-2.amazonaws.com"]         
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["content-type", "Access-Control-Allow-Origin"]
    max_age       = 3600
  }
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.visit_logger.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "visit_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.visit_logger.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}




output "website_endpoint" {
  value = aws_s3_bucket.resumes_bucket.website_endpoint
}

