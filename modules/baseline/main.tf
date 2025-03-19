locals {
  cluster_name = "cluster1"
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  cidr   = "10.0.0.0/16"

  name = "default"

  azs             = ["us-east-1a", "us-east-1b", ]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
}


module "eks" {
  source = "terraform-aws-modules/eks/aws"

  cluster_name    = local.cluster_name
  cluster_version = "1.31"

  # Gives Terraform identity admin access to cluster which will
  # allow deploying resources (Karpenter) into the cluster
  enable_cluster_creator_admin_permissions = true
  cluster_endpoint_public_access           = true

  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # TODO: as an enhancement implement karpenter
  eks_managed_node_groups = {
    default = {
      ami_type      = "BOTTLEROCKET_ARM_64"
      capacity_type = "SPOT"
      #Increase to a larger instance type if more performance is needed   
      instance_types = ["t4g.medium"]

      min_size     = 2
      max_size     = 3
      desired_size = 2
    }
  }
}


resource "aws_security_group" "eks_custom_sg" {
  name        = "${local.cluster_name}-sg"
  description = "Custom security group for EKS cluster"
  vpc_id      = module.vpc.vpc_id

  # Allow your IP to access services inside the cluster
  ingress {
    description = "Allow traffic from my IP"
    from_port   = 80 # Example: if you expose an HTTP service
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["23.93.120.120/32"]
  }

  # Allow all egress traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "sg_id" {
  value = aws_security_group.eks_custom_sg.id
}
