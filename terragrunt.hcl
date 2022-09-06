locals {
  environment_vars = try(read_terragrunt_config(find_in_parent_folders("env.hcl")), read_terragrunt_config("env.hcl"))

  # Extract the variables we need for easy access
  account_name = local.environment_vars.locals.account_name
  account_id   = local.environment_vars.locals.aws_account_id
  aws_region   = local.environment_vars.locals.aws_region
  env          = local.environment_vars.locals.env
}

# Generate an AWS provider block
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.aws_region}"

  # Only these AWS Account IDs may be operated on by this template
  allowed_account_ids = ["${local.account_id}"]
}
EOF
}

# Configure Terragrunt to automatically store tfstate files in an S3 bucket
remote_state {
  backend = "s3"
  config = {
    encrypt        = true
    bucket         = "danielcrisap-terraform-state-${local.account_name}-${local.aws_region}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    dynamodb_table = "terraform-locks"
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

inputs = merge(
  local.environment_vars,
)
