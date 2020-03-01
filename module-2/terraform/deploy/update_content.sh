set -eu

MODULE_1_DIR="../../../module-1"
MODULE_2_DIR="../.."
S3_BUCKET_NAME=$(terraform output -state="$MODULE_1_DIR/terraform/terraform.tfstate" static_content_bucket_name)
API_ENDPOINT_URL=$(terraform output api_endpoint_url)
sed "s/REPLACE_ME/http:\/\/$API_ENDPOINT_URL/g" "$MODULE_2_DIR/web/index.html" | aws s3 cp - "s3://$S3_BUCKET_NAME/index.html" --content-type text/html
