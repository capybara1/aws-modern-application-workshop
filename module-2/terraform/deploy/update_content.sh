set -eu

REPO_DIR=$(git rev-parse --show-toplevel)
MODULE_1_DIR="REPO_DIR/module-1"
MODULE_2_DIR="REPO_DIR/module-2"
S3_BUCKET_NAME=$(terraform output -state="$REPO_DIR/module-1/terraform/terraform.tfstate" static_content_bucket_name)
API_ENDPOINT_URL=$(terraform output api_endpoint_url)
sed "s/REPLACE_ME/http:\/\/$API_ENDPOINT_URL/g" "$REPO_DIR/module-2/web/index.html" | aws s3 cp - "s3://$S3_BUCKET_NAME/index.html" --content-type text/html
