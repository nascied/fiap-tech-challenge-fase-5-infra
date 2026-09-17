locals {
  resource_prefix_name = "fiap-tc-f5"

  # Tier de criticidade (ver docs/drp/DRP.md, seção 3) usado na tag FinOps `Tier`.
  # donation-service é o "Caminho Crítico / Hot Path" do hackathon -> Tier 0.
  tier_by_service = {
    "donation-service" = "0"
    "ngo-service"      = "1"
  }
}