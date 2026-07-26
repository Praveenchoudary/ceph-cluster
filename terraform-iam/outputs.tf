output "iam_role_arn" {
  value = aws_iam_role.ec2_s3_role.arn
}

output "iam_policy_arn" {
  value = aws_iam_policy.s3_read_only.arn
}

output "instance_profile_name" {
  value = aws_iam_instance_profile.ec2_profile.name
}

output "app_server_instance_id" {
  value = aws_instance.app_server.id
}

output "developer_user_arn" {
  value = aws_iam_user.developer.arn
}
