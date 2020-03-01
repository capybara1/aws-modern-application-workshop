provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

data "aws_caller_identity" "current" {}

locals {
  code_repo_name        = "mythicalmysfits-code-repo"
  image_repo_name       = "mythicalmysfits/service" # also referred to in buildspec.yml
  build_project_name    = "mythicalmysfits-web-api-build-project"
  build_pipeline_name   = "mythicalmysfits-web-api-build-pipeline"
  artifacts_bucket_name = "${data.aws_caller_identity.current.account_id}.mythicalmysfits.build"
}

resource "aws_codecommit_repository" "default" {
  repository_name = local.code_repo_name
  description     = "MythicalMysfits tutorial"
}

resource "aws_iam_user" "contributor" {
  name = "mysticalmysfits-contributor"
  path = "/"
  force_destroy = true
}

resource "aws_iam_user_policy" "codebuild" {
  name   = "contributor-policy"
  user   = aws_iam_user.contributor.name
  policy = data.aws_iam_policy_document.contributor_policy.json
}

resource "aws_ecr_repository" "default" {
  name                 = local.image_repo_name
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository_policy" "default" {
  repository = aws_ecr_repository.default.name
  policy     = <<EOT
{
  "Statement": [
    {
      "Sid": "AllowPushPull",
      "Effect": "Allow",
      "Principal": {
        "AWS": ["${aws_iam_role.codebuild.arn}"]
      },
      "Action": [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ]
    }
  ]
}
EOT
}

resource "aws_iam_role" "codebuild" {
  name               = "${local.build_project_name}-role"
  assume_role_policy = data.aws_iam_policy_document.code_builder_service_assume_role_policy.json
  path               = "/"
}

resource "aws_iam_role_policy" "codebuild" {
  name   = "${local.build_project_name}-policy"
  role   = aws_iam_role.codebuild.id
  policy = data.aws_iam_policy_document.code_builder_service_policy.json
}

resource "aws_codebuild_project" "web_api" {
  name         = local.build_project_name
  service_role = aws_iam_role.codebuild.id
  artifacts {
    type = "NO_ARTIFACTS"
  }
  environment {
    type            = "LINUX_CONTAINER"
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/python:3.5.2"
    privileged_mode = true
    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }
  }
  source {
    type     = "CODECOMMIT"
    location = aws_codecommit_repository.default.clone_url_http
  }
}

resource "aws_iam_role" "codepipeline" {
  name               = "${local.build_pipeline_name}-role"
  assume_role_policy = data.aws_iam_policy_document.code_pipeline_service_assume_role_policy.json
  path               = "/"
}

resource "aws_iam_role_policy" "codepipeline" {
  name   = "${local.build_pipeline_name}-policy"
  role   = aws_iam_role.codepipeline.id
  policy = data.aws_iam_policy_document.code_pipeline_service_policy.json
}

resource "aws_s3_bucket" "build_artifacts" {
  bucket = local.artifacts_bucket_name
  policy = <<EOT
{
  "Statement": [
    {
      "Sid": "WhitelistedGet",
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "${aws_iam_role.codebuild.arn}",
          "${aws_iam_role.codepipeline.arn}"
        ]
      },
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketVersioning"
      ],
      "Resource": [
        "arn:aws:s3:::${local.artifacts_bucket_name}/*",
        "arn:aws:s3:::${local.artifacts_bucket_name}"
      ]
    },
    {
      "Sid": "WhitelistedPut",
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "${aws_iam_role.codebuild.arn}",
          "${aws_iam_role.codepipeline.arn}"
        ]
      },
      "Action": "s3:PutObject",
      "Resource": [
        "arn:aws:s3:::${local.artifacts_bucket_name}/*",
        "arn:aws:s3:::${local.artifacts_bucket_name}"
      ]
    }
  ]
}
EOT
}

resource "aws_codepipeline" "web_api" {
  name     = local.build_pipeline_name
  role_arn = aws_iam_role.codepipeline.arn
  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.build_artifacts.id
  }
  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      input_artifacts  = []
      output_artifacts = ["MythicalMysfitsService-SourceArtifact"]
      configuration = {
        BranchName     = "master"
        RepositoryName = local.code_repo_name
      }
      run_order = 1
    }
  }
  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["MythicalMysfitsService-SourceArtifact"]
      output_artifacts = ["MythicalMysfitsService-BuildArtifact"]
      configuration = {
        ProjectName = local.build_project_name
      }
      run_order = 1
    }
  }
}

