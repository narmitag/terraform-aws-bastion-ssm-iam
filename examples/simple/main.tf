provider "aws" {
  region = "eu-west-2"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "simple-example"

  cidr = "10.0.0.0/16"

  azs             = ["eu-west-2a"]
  private_subnets = ["10.0.1.0/24"]
  public_subnets  = ["10.0.2.0/24"]

  enable_ipv6 = false

  enable_nat_gateway = false
  single_nat_gateway = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Owner       = "user"
    Environment = "dev"
  }

  vpc_tags = {
    Name = "vpc-name"
  }
}


module "terraform-aws-bastion-ssm-iam" {
  source = "../../"

  # The name used to interpolate in the resources, defaults to bastion-ssm-iam
  # name = "bastion-ssm-iam"

  # The vpc id
  vpc_id = module.vpc.vpc_id

  # subnet_ids designates the subnets where the bastion can reside
  subnet_ids = module.vpc.private_subnets
  

  # The module creates a security group for the bastion by default
  # create_security_group = true

  # The module can create a diffent ssm document for this deployment, to allow
  # different security models per BASTION deployment
  # create_new_ssm_document = false

  # It is possible to attach other security groups to the bastion.
  # security_group_ids = []
}
data "aws_security_group" "default" {
    name   = "default"
    vpc_id = module.vpc.vpc_id
}
resource "aws_security_group" "vpc_tls" {
  name_prefix = "neil-vpc_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

module "vpc_endpoints" {
    source = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
    version = "3.14.2"

    vpc_id             = module.vpc.vpc_id
    security_group_ids = [data.aws_security_group.default.id]

    endpoints = {
        s3 = {
        service = "s3"
        tags    = { Name = "neil-s3-vpc-endpoint" }
        },
       ssm = {
        service             = "ssm"
        private_dns_enabled = true
        subnet_ids          = module.vpc.private_subnets
        security_group_ids  = [aws_security_group.vpc_tls.id]
      },
      ssmmessages = {
        service             = "ssmmessages"
        private_dns_enabled = true
        subnet_ids          = module.vpc.private_subnets
                security_group_ids  = [aws_security_group.vpc_tls.id]
      },
      ec2 = {
        service             = "ec2"
        private_dns_enabled = true
        subnet_ids          = module.vpc.private_subnets
        security_group_ids  = [data.aws_security_group.default.id]
      },
      ec2messages = {
        service             = "ec2messages"
        private_dns_enabled = true
        subnet_ids          = module.vpc.private_subnets
                security_group_ids  = [aws_security_group.vpc_tls.id]
      },
      kms = {
        service             = "kms"
        private_dns_enabled = true
        subnet_ids          = module.vpc.private_subnets
        security_group_ids  = [aws_security_group.vpc_tls.id]
      },
      logs = {
        service             = "logs"
        private_dns_enabled = true
        subnet_ids          = module.vpc.private_subnets
                security_group_ids  = [aws_security_group.vpc_tls.id]
      },
    }

}