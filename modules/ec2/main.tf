data "aws_ami" "ubuntu" {
  count       = var.ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

locals {
  selected_ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu[0].id
}

resource "aws_instance" "bastion" {
  count = var.create_bastion ? 1 : 0

  ami                         = local.selected_ami_id
  instance_type               = var.bastion_instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [var.bastion_security_group_id]
  iam_instance_profile        = var.bastion_instance_profile
  key_name                    = var.key_name == "" ? null : var.key_name
  associate_public_ip_address = true
  disable_api_termination     = var.termination_protection
  monitoring                  = var.detailed_monitoring

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  root_block_device {
    encrypted             = true
    volume_type           = "gp3"
    volume_size           = var.bastion_root_volume_size
    delete_on_termination = true
  }

  user_data = <<-EOF
#!/bin/bash
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y \
  unzip \
  curl \
  jq \
  git \
  ca-certificates \
  gnupg

cd /tmp

curl -fsSLo awscliv2.zip https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip
unzip -q awscliv2.zip
./aws/install --update

KUBECTL_VERSION="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"

curl -fsSLo /usr/local/bin/kubectl \
  "https://dl.k8s.io/release/$${KUBECTL_VERSION}/bin/linux/amd64/kubectl"

chmod +x /usr/local/bin/kubectl

curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

rm -rf /tmp/aws /tmp/awscliv2.zip
EOF

  user_data_replace_on_change = true

  tags = merge(
    var.tags,
    {
      Name     = "${var.project_name}-${var.environment}-bastion"
      Role     = "administration"
      Critical = "true"
    }
  )
}

resource "aws_instance" "tools" {
  count = var.create_tools_host ? 1 : 0

  ami                         = local.selected_ami_id
  instance_type               = var.tools_instance_type
  subnet_id                   = var.tools_public_subnet_id
  vpc_security_group_ids      = [var.tools_security_group_id]
  iam_instance_profile        = var.tools_instance_profile
  key_name                    = var.key_name == "" ? null : var.key_name
  associate_public_ip_address = true
  disable_api_termination     = var.termination_protection
  monitoring                  = var.detailed_monitoring

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  root_block_device {
    encrypted             = true
    volume_type           = "gp3"
    volume_size           = var.tools_root_volume_size
    delete_on_termination = true
  }

  user_data = <<-EOF
#!/bin/bash
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update -y

apt-get install -y \
  unzip \
  curl \
  jq \
  git \
  ca-certificates \
  gnupg \
  fontconfig \
  openjdk-21-jdk \
  docker.io

systemctl enable --now docker

cd /tmp

curl -fsSLo awscliv2.zip https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip
unzip -q awscliv2.zip
./aws/install --update

KUBECTL_VERSION="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"

curl -fsSLo /usr/local/bin/kubectl \
  "https://dl.k8s.io/release/$${KUBECTL_VERSION}/bin/linux/amd64/kubectl"

chmod +x /usr/local/bin/kubectl

curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

install -m 0755 -d /etc/apt/keyrings

curl -fsSL \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key \
  -o /etc/apt/keyrings/jenkins-keyring.asc

echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
  > /etc/apt/sources.list.d/jenkins.list

apt-get update -y
apt-get install -y jenkins

usermod -aG docker jenkins

systemctl enable --now jenkins

sysctl -w vm.max_map_count=524288

cat > /etc/sysctl.d/99-sonarqube.conf <<'SYSCTL'
vm.max_map_count=524288
SYSCTL

sysctl --system

docker volume create sonarqube_data
docker volume create sonarqube_logs
docker volume create sonarqube_extensions

docker run -d \
  --name sonarqube \
  --restart unless-stopped \
  -p 9000:9000 \
  -v sonarqube_data:/opt/sonarqube/data \
  -v sonarqube_logs:/opt/sonarqube/logs \
  -v sonarqube_extensions:/opt/sonarqube/extensions \
  sonarqube:lts-community

rm -rf /tmp/aws /tmp/awscliv2.zip
EOF

  user_data_replace_on_change = true

  tags = merge(
    var.tags,
    {
      Name     = "${var.project_name}-${var.environment}-jenkins-sonarqube"
      Role     = "ci-code-quality"
      Critical = "true"
    }
  )
}
