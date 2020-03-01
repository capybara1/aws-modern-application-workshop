# Terraform for Module 2

## Assumption

- Resources of [module 1](../module-1/terraform/README.md#setup) still exist

## Setup

1) Create resources for CI with terraform:

```
pushd ci
terraform init
terraform apply
```

2) Use AWS IAM console to obtain git credentials for access to the repo
3) Clone repo
4) Copy content of `$REPO_ROOT/module-2/app` to cloned repo
5) Commit changes
6) Push changes

```
popd
push deploy
terraform init
terraform apply
./update_content.sh
popd
```

## Clean up

Destroy resources created within this module:

```
pushd deploy
terraform destroy
popd
pushd ci
terraform destroy
popd
```

Continue with [instructions for module 1](../module-1/terraform/README.md#clean_up)
