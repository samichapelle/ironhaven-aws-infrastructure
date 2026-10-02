resource "aws_iam_role" "management" {
  name        = "${local.name_prefix}-management-role"
  description = "IAM role for the Ironhaven management instance"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-management-role"
    Tier = "management"
  }
}

resource "aws_iam_role_policy_attachment" "management_ssm" {
  role       = aws_iam_role.management.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "management" {
  name = "${local.name_prefix}-management-profile"
  role = aws_iam_role.management.name

  tags = {
    Name = "${local.name_prefix}-management-profile"
    Tier = "management"
  }
}