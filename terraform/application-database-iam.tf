# Allow the application EC2 to authenticate only as the
# dedicated, read-only PostgreSQL account.
#
# The application IAM role has no permission to read the RDS master secret.

resource "aws_iam_role_policy" "application_database_connect" {
  name = "${local.name_prefix}-application-database-connect"
  role = aws_iam_role.application.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ConnectAsApplicationReader"
        Effect   = "Allow"
        Action   = "rds-db:connect"
        Resource = "arn:aws:rds-db:${var.aws_region}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_db_instance.postgresql.resource_id}/ironhaven_reader"
      }
    ]
  })
}
