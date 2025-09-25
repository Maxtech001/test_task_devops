# Configure the AWS provider with the region specified in variables
provider "aws" {
  region = var.aws_region
}
# Configure the Kubernetes provider to connect to the EKS cluster
provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}
# Get authentication token for the EKS cluster
data "aws_eks_cluster_auth" "this" {
  name = data.aws_eks_cluster.this.name
}  

# End of providers.tf