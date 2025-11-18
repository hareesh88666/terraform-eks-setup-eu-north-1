##############################################
# EKS Cluster
##############################################
resource "aws_eks_cluster" "eks" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.33"

  vpc_config {
    # Cluster should use **both** public and private subnets (TEMP until NAT created)
    subnet_ids = [
      aws_subnet.public["az1"].id,
      aws_subnet.public["az2"].id,
      aws_subnet.private["az1"].id,
      aws_subnet.private["az2"].id
    ]

    security_group_ids      = [aws_security_group.eks_nodes.id]
    endpoint_public_access  = true
    endpoint_private_access = false
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
# EKS Node Group (Deploy in PUBLIC subnets temporarily)
##############################################
resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = var.node_group_name

  node_role_arn = aws_iam_role.node_group.arn

  # TEMP: nodegroups in public until NAT added
  subnet_ids = [
    aws_subnet.public["az1"].id,
    aws_subnet.public["az2"].id
  ]

  scaling_config {
    desired_size = var.node_desired_capacity
    max_size     = var.node_max_size
    min_size     = var.node_min_size
  }

  instance_types = [var.node_instance_type]
  ami_type       = "AL2023_x86_64_STANDARD"

  tags = {
    Name = "${var.cluster_name}-nodegroup"
  }

  depends_on = [
    aws_eks_cluster.eks,
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
  ]
}

##############################################
# Install kubectl
##############################################
resource "null_resource" "install_kubectl" {
  provisioner "local-exec" {
    command = <<EOT
      echo "Installing kubectl..."
      curl -LO "https://dl.k8s.io/release/v1.33.0/bin/linux/amd64/kubectl"
      chmod +x kubectl
      sudo mv kubectl /usr/local/bin/
      kubectl version --client
    EOT
  }
}

##############################################
# Configure kubectl
##############################################
resource "null_resource" "configure_kubectl" {
  depends_on = [
    aws_eks_node_group.default,
    null_resource.install_kubectl
  ]

  provisioner "local-exec" {
    command = <<EOT
      echo "Configuring kubectl..."
      aws eks update-kubeconfig --name ${aws_eks_cluster.eks.name} --region ${var.aws_region}
      kubectl get nodes
    EOT
  }
}

