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


resource "aws_dynamodb_table" "site_visits" {
  name         = "site_visits"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "visit_id"

  attribute {
    name = "visit_id"
    type = "S"
  }
}



resource "aws_security_group" "instance_sg" {
  name        = "instance-sg"
  description = "Allow SSH and HTTP traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080 
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "instance-sg"
  }
}

resource "aws_iam_role" "instance_dynamo" {
  name = "instance_dynamo_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "instance_policy" {
  name = "instance_policy"
  role = aws_iam_role.instance_dynamo.name
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

data "archive_file" "instance_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../backend"
  output_path = "${path.module}/backend.zip"
}

resource "aws_iam_instance_profile" "infrademo_instance_profile" {
  name = "infrademo_instance_profile"
  role = aws_iam_role.instance_dynamo.name
}

resource "aws_instance" "app_instance" {
  ami                    = "ami-0c803b171269e2d72"
  iam_instance_profile   = aws_iam_instance_profile.infrademo_instance_profile.name
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  user_data              = file("${path.module}/../backend/user_data.sh")

  tags = {
    Name = "Node.js App Instance"
  }
}



output "public_ip" {
  value = aws_instance.app_instance.public_ip
}


