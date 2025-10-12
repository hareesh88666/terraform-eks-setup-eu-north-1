##############################################
# EKS Cluster
##############################################
resource "aws_eks_cluster" "eks" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn

  version  = "1.33" # match your current cluster version ✅

  vpc_config {
    subnet_ids              = concat(values(aws_subnet.public)[*].id, values(aws_subnet.private)[*].id)
    security_group_ids      = [aws_security_group.eks_nodes.id]
    endpoint_public_access  = true   # ✅ ensures worker nodes can reach API server
    endpoint_private_access = false  # ✅ disable private-only (you can enable later)
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = {
    Name = var.cluster_name
  }
}

##############################################
# EKS Cluster Data
##############################################
data "aws_eks_cluster" "eks" {
  name       = aws_eks_cluster.eks.name
  depends_on = [aws_eks_cluster.eks]
}

data "aws_eks_cluster_auth" "eks" {
  name = aws_eks_cluster.eks.name
}

##############################################
# EKS Node Group
##############################################
resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = var.node_group_name
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = values(aws_subnet.public)[*].id 

  scaling_config {
    desired_size = var.node_desired_capacity
    max_size     = var.node_max_size
    min_size     = var.node_min_size
  }

  instance_types = [var.node_instance_type]
  ami_type       = "AL2023_x86_64_STANDARD"  # ✅ correct for Kubernetes 1.33

  tags = {
    Name = "${var.cluster_name}-nodegroup"
  }

  depends_on = [
    aws_eks_cluster.eks,  # ✅ ensures cluster is fully ready first
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly
  ]
}


##############################################
# Install kubectl (official Kubernetes release)
##############################################
resource "null_resource" "install_kubectl" {
  provisioner "local-exec" {
    command = <<EOT
      echo "🔧 Installing kubectl from official Kubernetes source..."
      curl -LO "https://dl.k8s.io/release/v1.33.0/bin/linux/amd64/kubectl"
      chmod +x kubectl
      sudo mv kubectl /usr/local/bin/
      echo "✅ kubectl installed successfully:"
      kubectl version --client
    EOT
  }
}

##############################################
# Configure kubectl for the new EKS cluster
##############################################
resource "null_resource" "configure_kubectl" {
  depends_on = [
    aws_eks_node_group.default,
    null_resource.install_kubectl
  ]

  provisioner "local-exec" {
    command = <<EOT
      echo "🔧 Configuring kubectl for EKS cluster..."
      aws eks update-kubeconfig --name ${aws_eks_cluster.eks.name} --region ${var.aws_region}
      echo "✅ kubeconfig updated!"
      kubectl get nodes
    EOT
  }
}

