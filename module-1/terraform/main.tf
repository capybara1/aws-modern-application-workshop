provider "aws" {
  profile = "default"
  region  = var.aws_region
}

resource "aws_s3_bucket" "static_files" {
  bucket = "s3-website.mythicalmysfits"
  acl = "public-read"
  policy = file("../aws-cli/website-bucket-policy.json")
  website {
    index_document = "index.html"
  }
}
