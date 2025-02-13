module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.19.0"

  name = "${var.env}-vpc"

  cidr                  = "10.0.0.0/16"
  secondary_cidr_blocks = ["100.64.0.0/16"]

  azs = ["${var.region}a", "${var.region}b", "${var.region}c"]

  # For use on ALBs, ApiGateways and External facing applications.
  public_subnets = ["10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/20"]
  public_subnet_tags = {
    "kubernetes.io/cluster/${var.env}" = "owned"
    "kubernetes.io/role/elb"           = 1
  }

  # For main use, all nodes and provide applications.
  # Available subnet blocks
  # "10.0.96.0/20" "10.0.112.0/20" "10.0.128.0/20"
  # "10.0.144.0/20" "10.0.160.0/20" "10.0.176.0/20"
  #  private_subnets = ["10.0.48.0/20", "10.0.64.0/20", "10.0.80.0/20"]

  # For use on datastore applications, like RDS, Elasticache, DocumentDB, and so on.
  #  database_subnets = ["10.0.192.0/20", "10.0.208.0/20", "10.0.224.0/20"]

  enable_ipv6        = false
  enable_classiclink = false

  enable_nat_gateway     = false
  single_nat_gateway     = false
  one_nat_gateway_per_az = false
  enable_vpn_gateway     = false

  tags = local.tags
}

locals {
  k8s_subnets = cidrsubnets("100.64.0.0/16", 3, 3, 3)
}

# https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html
# https://docs.aws.amazon.com/vpc/latest/userguide/working-with-vpcs.html#add-ipv4-cidr
resource "aws_subnet" "k8s_extra_subnet" {
  for_each = zipmap(module.vpc.azs, local.k8s_subnets)

  vpc_id            = module.vpc.vpc_id
  availability_zone = each.key
  cidr_block        = each.value

  tags = merge(local.tags, {
    Name                               = "${var.env}-vpc-k8s-${each.key}"
    "kubernetes.io/cluster/${var.env}" = "owned"
    "kubernetes.io/role/internal-elb"  = 1
  })
  depends_on = [
    module.vpc
  ]
}

resource "aws_route_table_association" "k8s_rt_assoc" {
  for_each       = toset(module.vpc.azs)
  subnet_id      = aws_subnet.k8s_extra_subnet[each.key].id
  route_table_id = module.vpc.public_route_table_ids[0]
  depends_on = [
    aws_subnet.k8s_extra_subnet
  ]
}
