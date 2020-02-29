set -eu

S3_BUCKET_NAME=$(terraform output static_content_bucket_name)
aws s3 cp ../web/index.html s3://$S3_BUCKET_NAME/index.html
