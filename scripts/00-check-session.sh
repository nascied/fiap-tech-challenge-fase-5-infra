#!/usr/bin/env bash
# Confere se a sessão de credenciais temporárias da AWS Academy (~4h) está
# ativa antes de rodar qualquer coisa que precise falar com a AWS de verdade.
#
# Uso: ./00-check-session.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

check_aws_session
