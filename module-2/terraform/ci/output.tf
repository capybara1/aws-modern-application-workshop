output "code_repo_url" {
  value = aws_codecommit_repository.default.clone_url_http
}

output "image_repo_url" {
  value = aws_ecr_repository.default.repository_url
}
