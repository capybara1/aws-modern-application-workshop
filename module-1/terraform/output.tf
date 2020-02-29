output "address" {
  value = aws_s3_bucket.static_files.website_endpoint
}

output "static_content_bucket_name" {
  value = aws_s3_bucket.static_files.id
}
