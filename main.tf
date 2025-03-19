provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Environment = "dev"
      Project     = "aws.account.tf"
      Terraform   = "true"
    }
  }
}

module "baseline" {
  source = "./modules/baseline"
}

import {
  to = module.baseline.module.vpc.aws_vpc.this[0]
  id = "vpc-07a938ee716c839fc"
}


import {
  to = module.baseline.module.vpc.aws_subnet.private[0]
  id = "subnet-08171f04224a538e2"
}

import {
  to = module.baseline.module.vpc.aws_subnet.private[1]
  id = "subnet-0749cdccbafb54d1e"
}

output "sg_id" {
  value = module.baseline.sg_id
}
