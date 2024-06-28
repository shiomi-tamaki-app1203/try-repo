# main.tf
provider "aws" {
  region = "us-west-2"
}

# S3バケットの定義
resource "aws_s3_bucket" "frontend_bucket" {
  bucket = "your-bucket-name"
  acl    = "public-read"
}

 website {
    index_document = "index.html"
    error_document = "error.html"
  }

# CloudFrontディストリビューションの定義
resource "aws_cloudfront_distribution" "frontend_distribution" {
  origin {
    domain_name = "${aws_s3_bucket.frontend_bucket.bucket_regional_domain_name}"
    origin_id   = "S3-${aws_s3_bucket.frontend_bucket.id}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "S3 frontend distribution"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "S3-${aws_s3_bucket.frontend_bucket.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_100"

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

#RDSインスタンスの定義
resource "aws_db_instance" "db_instance" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  name                 = "mydatabase"
  username             = "admin"
  password             = "password"
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
}

#Lambda関数の定義
resource "aws_lambda_function" "backend_function" {
  function_name = "my_lambda_function"
  runtime       = "python3.8"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "handler.lambda_handler"
  filename      = "path/to/your/lambda_function.zip"

  environment {
    variables = {
      DB_HOST     = aws_db_instance.db_instance.endpoint
      DB_USER     = "admin"
      DB_PASSWORD = "password"
    }
  }
}

#API Gatewayの定義
resource "aws_api_gateway_rest_api" "api" {
  name        = "MyAPI"
  description = "This is my API for Lambda"
}

resource "aws_api_gateway_resource" "resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "myresource"
}

resource "aws_api_gateway_method" "method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.resource.id
  http_method = aws_api_gateway_method.method.http_method
  type        = "AWS_PROXY"
  uri         = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.backend_function.arn}/invocations"

  integration_http_method = "POST"
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backend_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.api.id}/*/*"
}

