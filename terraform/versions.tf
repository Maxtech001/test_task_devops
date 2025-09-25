# Specify the required Terraform and provider versions
terraform {
  # Ensure Terraform CLI version is at least 1.5.0
  required_version = ">= 1.5.0"

  required_providers {
    # Define the AWS provider from HashiCorp with minimum version 5.0
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# end of versions.tf