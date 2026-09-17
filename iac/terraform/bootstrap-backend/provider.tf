provider "aws" {

  default_tags {
    tags = {
      ManagedBy  = "terraform"
      Project    = "SolidaryTech"
      CostCenter = "NGO-Core"
    }
  }
}