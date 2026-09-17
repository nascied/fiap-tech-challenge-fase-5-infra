output "aws_s3_bucket_id" {
  value      = local.bucket_name
  depends_on = [null_resource.bucket]
}

output "aws_s3_bucket_arn" {
  value      = "arn:aws:s3:::${local.bucket_name}"
  depends_on = [null_resource.bucket]
}

output "aws_s3_bucket_bucket_domain_name" {
  value      = "${local.bucket_name}.s3.amazonaws.com"
  depends_on = [null_resource.bucket]
}
