# Private application EC2 instance

resource "aws_iam_role" "application" {
  name = "${local.name_prefix}-application-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${local.name_prefix}-application-role"
    Tier = "application"
  }
}

resource "aws_iam_role_policy_attachment" "application_ssm" {
  role       = aws_iam_role.application.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "application" {
  name = "${local.name_prefix}-application-profile"
  role = aws_iam_role.application.name
}

resource "aws_instance" "application" {
  # Pinned to the AMI used by the deployed application EC2 to avoid replacement on a newer AL2023 release.
  ami                    = "ami-018ced63cf0e10415"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_app.id
  vpc_security_group_ids = [aws_security_group.application.id]
  iam_instance_profile   = aws_iam_instance_profile.application.name

  associate_public_ip_address = false

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${local.name_prefix}-application"
    Tier = "application"
    Role = "application-server"
  }
}

output "application_instance_id" {
  value = aws_instance.application.id
}

output "application_private_ip" {
  value = aws_instance.application.private_ip
}
