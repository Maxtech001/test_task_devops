# eks-nodegroup.tf  (Managed Node Group only)
# - Uses existing EKS cluster: interview-solution-eks
# - Picks ONLY public subnets (MapPublicIpOnLaunch = true)
# - Creates a 2-node managed node group
############################################

# Discover the existing cluster
data "aws_eks_cluster" "this" {
  name = "interview-solution-eks"
}

# Find subnets in the same VPC that are tagged for this cluster
data "aws_subnets" "shared" {
  filter {
    name   = "vpc-id"
    values = [data.aws_eks_cluster.this.vpc_config[0].vpc_id]
  }
  filter {
    name   = "tag:kubernetes.io/cluster/interview-solution-eks"
    values = ["shared"]
  }
}

data "aws_subnets" "owned" {
  filter {
    name   = "vpc-id"
    values = [data.aws_eks_cluster.this.vpc_config[0].vpc_id]
  }
  filter {
    name   = "tag:kubernetes.io/cluster/interview-solution-eks"
    values = ["owned"]
  }
}

#Load each subnet to check if it auto-assigns public IPs
data "aws_subnet" "by_id" {
  for_each = toset(concat(data.aws_subnets.shared.ids, data.aws_subnets.owned.ids))
  id       = each.value
}

# Keep only public subnets
locals {
  public_cluster_subnet_ids = [
    for s in data.aws_subnet.by_id : s.id if s.map_public_ip_on_launch
  ]
}

# Create the Managed Node Group (UPDATED)
module "eks_mng_default" {
  source  = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  version = "~> 20.0"

  # Existing cluster details
  cluster_name         = data.aws_eks_cluster.this.name
  cluster_service_cidr = "172.20.0.0/16"    

  # Node group settings
  name            = "default-tf"
  subnet_ids      = local.public_cluster_subnet_ids
  create_iam_role = true

  # instance types Free-Tier-eligible  in this region
  instance_types = ["t3.small"]     # x86_64 Free-Tier-eligible in your account/region
  ami_type       = "AL2_x86_64"     # x86_64 for t3.* / c7i-flex / m7i-flex
  

  capacity_type  = "ON_DEMAND"

  min_size     = 2
  desired_size = 2
  max_size     = 3

  # Extra breathing room for slower accounts/regions
  timeouts = {
    create = "20m"
    update = "20m"
    delete = "20m"
  }

  tags = {
    "terraform-aws-modules" = "eks-managed-node-group-only"
  }
}

# End of eks-nodegroup.tf