# Terraform for Module 2

## Assummption

- Resources of module 1 still exist

## Setup

1) Create resources for CI with terraform:

```
terraform apply ci
```

2) Use AWS IAM console to obtain git credentials for access to the repo
3) Clone repo
4) Copy content of `/module-2/app` to cloned repo
5) Commit changes
6) Push changes

```
./update_content.sh
```

## Clean up

Destroy resources created within this module:

```
terraform destroy ci
```
