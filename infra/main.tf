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

resource "aws_dynamodb_table" "contact_messages" {
  name         = "contact_messages"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "message_id"

  attribute {
    name = "message_id"
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
    from_port   = 80
    to_port     = 80
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


resource "aws_iam_instance_profile" "infrademo_instance_profile" {
  name = "infrademo_instance_profile"
  role = aws_iam_role.instance_dynamo.name
}

resource "aws_instance" "app_instance" {
  ami                    = "ami-0c803b171269e2d72"
  key_name               = "infra-demo-keys"
  iam_instance_profile   = aws_iam_instance_profile.infrademo_instance_profile.name
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.instance_sg.id]

  user_data = <<EOF
#!/bin/bash
exec > /var/log/user-data.log 2>&1
set -ex
echo "User data script started"
sudo yum update -y
sudo yum install -y iptables
sudo yum install -y git
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
sudo -i -u ec2-user bash <<'EOC'
cd /home/ec2-user
export NVM_DIR="/home/ec2-user/.nvm"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install --lts
nvm use --lts
git clone -b main https://github.com/tristenkelly/infra-demo /home/ec2-user/app
cd /home/ec2-user/app/frontend
npm install
npm install -g pm2
npm install express
npm install @aws-sdk/client-dynamodb
pm2 start source.mjs --name resume-app --env PORT=8080

EOC
echo "User data script finished"
EOF

  tags = {
    Name = "Resume App Instance"
  }
}



output "public_ip" {
  value = aws_instance.app_instance.public_ip
}


