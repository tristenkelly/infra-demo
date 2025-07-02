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