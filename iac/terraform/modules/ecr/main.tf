resource "aws_ecr_repository" "this" {
  for_each = toset(local.repository_name)
  name     = "${each.value}-reg"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Service = "${trimprefix(each.value, "${local.resource_prefix_name}-")}-service"
  }
}

