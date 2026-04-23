output "instance_id" {
  value = aws_instance.host.id
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}

output "artifacts_bucket" {
  value = aws_s3_bucket.artifacts.bucket
}

output "bootstrap_bundle_uri_template" {
  value = "s3://${aws_s3_bucket.artifacts.bucket}/bundles/<bundle>.tar.gz"
}

output "ssm_target" {
  value = aws_instance.host.id
}

output "public_ip" {
  value = aws_instance.host.public_ip
}

output "public_dns" {
  value = aws_instance.host.public_dns
}

output "cloudfront_domain" {
  value = var.enable_public_rpc ? aws_cloudfront_distribution.public_rpc[0].domain_name : ""
}

output "public_rpc_url" {
  value = var.enable_public_rpc ? "https://${aws_cloudfront_distribution.public_rpc[0].domain_name}" : ""
}

output "release_records_prefix" {
  value = "s3://${aws_s3_bucket.artifacts.bucket}/releases"
}
