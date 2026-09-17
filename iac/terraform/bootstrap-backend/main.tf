resource "aws_s3_bucket" "this" {
  bucket = "${local.resource_prefix_name}-${var.aws_s3_bucket_name}"
}