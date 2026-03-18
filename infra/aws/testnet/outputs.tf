output "instance_id" {
  value = aws_instance.host.id
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}

output "artifacts_bucket" {
  value = aws_s3_bucket.artifacts.bucket
}

output "proof_queue_url" {
  value = aws_sqs_queue.proof.id
}

output "proof_queue_name" {
  value = aws_sqs_queue.proof.name
}

output "bootstrap_bundle_uri_template" {
  value = "s3://${aws_s3_bucket.artifacts.bucket}/bundles/<bundle>.tar.gz"
}

output "ssm_target" {
  value = aws_instance.host.id
}
