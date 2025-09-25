
# Simple HA EC2 + Kubernetes Manifests (eu-west-1)

## Task 1 (Terraform)
Creates:
- VPC with 2 public subnets across 2 AZs in `eu-west-1`
- Security Group allowing SSH/HTTP **only** from `88.196.208.91/32`
- Auto Scaling Group (desired=1) with a Launch Template
  - Amazon Linux 2023
  - Two extra EBS volumes: `/dev/xvdb` and `/dev/xvdc` (10 GiB each)
  - User data mounts the volumes and serves a Hello page on port 80

### Deploy
```bash
cd terraform
terraform init
terraform validate
terraform plan 
terraform apply -auto-approve
```

Outputs include the ASG instance IDs; check the EC2 console for the public IP. Access is limited to `88.196.208.91/32`.

## Task 2 (Kubernetes)
Manifests for a deployment named **my-k8s-deployment** with label `app: my-app`:
- **Container 1**: `busybox:latest` prints the current date every minute.
- **Container 2**: `nginxdemos/hello:latest` web server with readiness/liveness probes and resources.
- Exposed via a ClusterIP Service and an **Ingress** restricted to `88.196.208.91/32` via nginx whitelist annotation.

### Apply (to your EKS context)
```bash
kubectl apply -f k8s/deployment.yaml
```
#### Author###
Jude Ifeany Eze
