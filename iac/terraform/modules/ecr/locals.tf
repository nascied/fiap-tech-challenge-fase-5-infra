locals {
  resource_prefix_name = "fiap-tc-f5"
  repository_name = ["${local.resource_prefix_name}-ngo",
    "${local.resource_prefix_name}-donation",
  "${local.resource_prefix_name}-volunteer"]
}