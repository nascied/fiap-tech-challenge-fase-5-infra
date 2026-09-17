# Atalhos para scripts/. Uso: make <target> [ENV=dev|prd] (default ENV=dev).
# Ver scripts/README.md para o que cada passo faz e pré-requisitos.

ENV ?= dev
SCRIPTS := scripts

.PHONY: help check-session bootstrap init fmt validate test plan apply kubeconfig destroy all

help:
	@echo "Targets disponíveis (ENV=dev|prd, default dev):"
	@echo "  make check-session   - confere sessão AWS Academy ativa"
	@echo "  make bootstrap       - cria/atualiza o bucket S3 do state remoto"
	@echo "  make init            - terraform init (ENV=$(ENV))"
	@echo "  make fmt validate    - fmt -check + validate + tflint"
	@echo "  make test            - terraform test (mock_provider, sem AWS real)"
	@echo "  make plan            - terraform plan -> iac/terraform/tfplan (ENV=$(ENV))"
	@echo "  make apply           - aplica o tfplan salvo (ENV=$(ENV), com confirmação)"
	@echo "  make kubeconfig      - aws eks update-kubeconfig + kubectl get nodes"
	@echo "  make destroy         - terraform destroy (ENV=$(ENV), com dupla confirmação)"
	@echo "  make all             - roda o fluxo completo: check-session -> ... -> kubeconfig"

check-session:
	@$(SCRIPTS)/00-check-session.sh

bootstrap:
	@$(SCRIPTS)/01-bootstrap-backend.sh

init:
	@$(SCRIPTS)/02-init.sh $(ENV)

fmt validate:
	@$(SCRIPTS)/03-fmt-validate.sh

test:
	@$(SCRIPTS)/04-test.sh

plan:
	@$(SCRIPTS)/05-plan.sh $(ENV)

apply:
	@$(SCRIPTS)/06-apply.sh $(ENV)

kubeconfig:
	@$(SCRIPTS)/07-update-kubeconfig.sh

destroy:
	@$(SCRIPTS)/08-destroy.sh $(ENV)

all:
	@$(SCRIPTS)/run-all.sh $(ENV)
