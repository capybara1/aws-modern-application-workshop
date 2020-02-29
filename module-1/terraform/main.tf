provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "static_files" {
  bucket = "${data.aws_caller_identity.current.account_id}.mythicalmysfits"
  acl = "public-read"
  policy = <<EOT
{
  "Id": "MyPolicy",
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadForGetBucketObjects",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${data.aws_caller_identity.current.account_id}.mythicalmysfits/*"
    }
  ]
}
EOT
  website {
    index_document = "index.html"
  }
}
