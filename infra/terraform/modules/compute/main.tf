locals {
  tags = merge({
    Name = "n8n-poc-instance"
  }, var.tags)
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = [var.ami_owner]

  filter {
    name   = "name"
    values = [var.ami_name_filter]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_iam_role" "n8n" {
  name_prefix = "n8n-poc-ec2-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = local.tags
}

resource "aws_iam_instance_profile" "n8n" {
  name_prefix = "n8n-poc-ec2-profile-"
  role        = aws_iam_role.n8n.name
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.n8n.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_instance" "n8n" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.security_group_id]
  key_name                    = var.ssh_key_name
  user_data                   = var.user_data
  iam_instance_profile        = aws_iam_instance_profile.n8n.name
  associate_public_ip_address = !var.enable_elastic_ip

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true
  }

  tags = local.tags
}

resource "aws_eip" "n8n" {
  count      = var.enable_elastic_ip ? 1 : 0
  domain     = "vpc"
  instance   = aws_instance.n8n.id
  depends_on = [aws_instance.n8n]

  tags = local.tags
}
