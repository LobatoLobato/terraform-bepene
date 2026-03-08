terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Default provider
provider "aws" {
  region = "sa-east-1"
}

# Regional providers
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "sa_east_1"
  region = "sa-east-1"
}