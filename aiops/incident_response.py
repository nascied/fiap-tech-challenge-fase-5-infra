#!/usr/bin/env python3
"""Self-healing de incidentes SolidaryTech (ITSM/AIOps).

Fluxo: PagerDuty (incident.triggered) -> Lambda-ponte -> GitHub Actions
(repository_dispatch) -> este script.

O script recebe o contexto de um incidente do PagerDuty, pede pro Claude
decidir se um "rollout restart" do Deployment afetado é uma ação sensata, e
se for, executa via kubectl (kubeconfig já configurado pelo workflow antes de
chamar este script). Toda decisão e ação é logada em JSON estruturado no
stdout (captura do GitHub Actions), reportada no Slack, e o incidente é
resolvido no PagerDuty quando a ação é bem-sucedida.

Uso:
    # via workflow (payload vem do repository_dispatch)
    INCIDENT_PAYLOAD='{"pagerduty_event": {...}}' python incident_response.py

    # teste local com um payload simulado, sem precisar de PagerDuty/GitHub/EKS real
    python incident_response.py --payload-file aiops/fixtures/sample_incident.json --dry-run
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from typing import Any

import anthropic
import requests

MODEL = "claude-sonnet-5"

# service -> namespace K8s (os 3 microsserviços rodam todos no mesmo namespace
# hoje, ver fiap-tech-challenge-fase-5-observability/CLAUDE.md "namespace=fiap-tc-f5")
ALLOWED_SERVICES = {
    "donation-service": "fiap-tc-f5",
    "ngo-service": "fiap-tc-f5",
    "volunteer-service": "fiap-tc-f5",
}

SYSTEM_PROMPT = """\
Você é o agente de self-healing da plataforma SolidaryTech (ONGs, doações, \
voluntários). Você recebe o contexto de um incidente que chegou ao PagerDuty, \
originado de uma regra de burn rate de SLO (Prometheus/Alertmanager).

Sua única ação disponível é reiniciar (rollout restart) o Deployment do \
serviço afetado no Kubernetes. Só chame a tool restart_deployment quando o \
sintoma for do tipo que um restart plausivelmente resolve: processo travado, \
vazamento de memória, estado interno corrompido, taxa de erro 5xx elevada \
sem indicação de causa externa. NÃO chame a tool se o sintoma indicar uma \
causa externa que um restart não resolve (banco de dados fora do ar, fila \
travada, dependência de rede) — nesse caso, explique o porquê em texto e não \
chame nenhuma tool.

Sempre explique seu raciocínio de forma curta e objetiva antes ou depois de \
decidir. Essa explicação vira registro de auditoria do incidente.
"""

RESTART_TOOL = {
    "name": "restart_deployment",
    "description": (
        "Reinicia (kubectl rollout restart) o Deployment de um dos microsserviços "
        "da SolidaryTech no cluster EKS. Use quando o sintoma do incidente for do "
        "tipo que um restart tende a resolver (processo travado, vazamento de "
        "memória, estado interno corrompido, taxa de erro 5xx sem causa externa "
        "óbvia). Não use para problemas de dependência externa (banco de dados, "
        "fila) que um restart da aplicação não resolve."
    ),
    "input_schema": {
        "type": "object",
        "properties": {
            "service": {
                "type": "string",
                "enum": sorted(ALLOWED_SERVICES.keys()),
                "description": "Nome do microsserviço cujo Deployment deve ser reiniciado.",
            },
            "reason": {
                "type": "string",
                "description": "Justificativa curta da decisão — vai para o log de auditoria e a mensagem do Slack.",
            },
        },
        "required": ["service", "reason"],
        "additionalProperties": False,
    },
    "strict": True,
}


def log_event(**fields: Any) -> None:
    """Log estruturado em JSON (uma linha) — captura do GitHub Actions vira o registro de auditoria."""
    record = {"ts": datetime.now(timezone.utc).isoformat(), **fields}
    print(json.dumps(record, ensure_ascii=False), flush=True)


def extract_service_name(payload: dict) -> str | None:
    """Acha qual dos 3 serviços conhecidos está envolvido no incidente.

    Evita depender do formato exato de custom_details do webhook V3 do
    PagerDuty (não confirmado ao vivo nesta sessão — ver aiops/README.md).
    Em vez disso, procura o nome do serviço em qualquer texto do payload
    (título/descrição/summary), que é o campo mais estável entre versões
    da API do PagerDuty.
    """
    haystack = json.dumps(payload, ensure_ascii=False).lower()
    for service in ALLOWED_SERVICES:
        if service in haystack:
            return service
    return None


def extract_incident_id(payload: dict) -> str | None:
    """Tenta achar o ID do incidente no payload do webhook V3 do PagerDuty
    (event.data.id — formato não confirmado ao vivo nesta sessão, ver README)."""
    event = payload.get("pagerduty_event", payload).get("event", {})
    data = event.get("data", {})
    return data.get("id")


def build_incident_summary(payload: dict, service: str | None) -> str:
    event = payload.get("pagerduty_event", payload).get("event", {})
    data = event.get("data", {})
    title = data.get("title") or data.get("summary") or "(sem título no payload)"
    return (
        f"Serviço identificado: {service or 'desconhecido'}\n"
        f"Título do incidente: {title}\n"
        f"Payload bruto (referência): {json.dumps(payload, ensure_ascii=False)[:4000]}"
    )


def execute_restart(service: str, dry_run: bool) -> dict:
    if service not in ALLOWED_SERVICES:
        return {"ok": False, "error": f"serviço '{service}' não está na allowlist"}

    namespace = ALLOWED_SERVICES[service]
    cmd = ["kubectl", "rollout", "restart", f"deployment/{service}", "-n", namespace]

    if dry_run:
        log_event(event="restart_skipped_dry_run", service=service, cmd=" ".join(cmd))
        return {"ok": True, "dry_run": True, "cmd": " ".join(cmd)}

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30, check=False)
    except (subprocess.TimeoutExpired, OSError) as exc:
        return {"ok": False, "error": str(exc)}

    return {
        "ok": result.returncode == 0,
        "returncode": result.returncode,
        "stdout": result.stdout.strip(),
        "stderr": result.stderr.strip(),
    }


def notify_slack(text: str) -> None:
    webhook_url = os.environ.get("INCIDENT_SLACK_WEBHOOK_URL")
    if not webhook_url:
        log_event(event="slack_skipped", reason="INCIDENT_SLACK_WEBHOOK_URL não configurado")
        return
    try:
        resp = requests.post(webhook_url, json={"text": text}, timeout=10)
        resp.raise_for_status()
    except requests.RequestException as exc:
        log_event(event="slack_failed", error=str(exc))


def resolve_pagerduty_incident(incident_id: str | None) -> None:
    """Resolve o incidente via REST API do PagerDuty (PUT /incidents/{id}).

    Formato assumido, NÃO confirmado ao vivo nesta sessão (a documentação do
    PagerDuty é renderizada via JS e o WebFetch não conseguiu extrair o
    conteúdo) — confirmar contra https://developer.pagerduty.com antes de
    depender disso em produção. Falha aqui não é fatal: o incidente
    simplesmente continua aberto no PagerDuty pra alguém fechar manualmente.
    """
    token = os.environ.get("PAGERDUTY_API_TOKEN")
    from_email = os.environ.get("PAGERDUTY_FROM_EMAIL")
    if not token or not from_email or not incident_id:
        log_event(
            event="pagerduty_resolve_skipped",
            reason="faltando PAGERDUTY_API_TOKEN/PAGERDUTY_FROM_EMAIL/incident_id",
        )
        return

    try:
        resp = requests.put(
            f"https://api.pagerduty.com/incidents/{incident_id}",
            headers={
                "Authorization": f"Token token={token}",
                "From": from_email,
                "Content-Type": "application/json",
                "Accept": "application/vnd.pagerduty+json;version=2",
            },
            json={"incident": {"type": "incident_reference", "status": "resolved"}},
            timeout=10,
        )
        resp.raise_for_status()
        log_event(event="pagerduty_resolved", incident_id=incident_id)
    except requests.RequestException as exc:
        log_event(event="pagerduty_resolve_failed", incident_id=incident_id, error=str(exc))


def run_agent(payload: dict, dry_run: bool) -> int:
    service = extract_service_name(payload)
    incident_id = extract_incident_id(payload)
    summary = build_incident_summary(payload, service)

    log_event(event="incident_received", service=service, incident_id=incident_id)

    client = anthropic.Anthropic()
    messages = [{"role": "user", "content": summary}]
    tools = [RESTART_TOOL]

    action_taken = None
    final_text_parts: list[str] = []

    # Loop curto e limitado — no máximo uma decisão de restart por incidente.
    max_iterations = 3
    for _ in range(max_iterations):
        response = client.messages.create(
            model=MODEL,
            max_tokens=1024,
            system=SYSTEM_PROMPT,
            tools=tools,
            messages=messages,
        )

        for block in response.content:
            if block.type == "text":
                final_text_parts.append(block.text)

        if response.stop_reason != "tool_use":
            break

        messages.append({"role": "assistant", "content": response.content})

        tool_results = []
        for block in response.content:
            if block.type != "tool_use":
                continue
            if block.name == "restart_deployment":
                target_service = block.input["service"]
                reason = block.input["reason"]
                log_event(
                    event="restart_decided",
                    service=target_service,
                    reason=reason,
                    dry_run=dry_run,
                )
                result = execute_restart(target_service, dry_run)
                action_taken = {"service": target_service, "reason": reason, "result": result}
                tool_results.append(
                    {
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": json.dumps(result),
                        "is_error": not result.get("ok", False),
                    }
                )
        messages.append({"role": "user", "content": tool_results})

    reasoning = "\n".join(final_text_parts).strip()
    log_event(event="agent_finished", action_taken=action_taken, reasoning=reasoning)

    slack_lines = [
        f"*Incidente SolidaryTech — self-healing*",
        f"Serviço: `{service or 'desconhecido'}`",
        f"Raciocínio do Claude: {reasoning or '(sem texto)'}",
    ]
    if action_taken:
        ok = action_taken["result"].get("ok")
        status = "restart executado" if ok and not dry_run else "restart simulado (dry-run)" if dry_run else "restart FALHOU"
        slack_lines.append(f"Ação: {status} em `{action_taken['service']}` — {action_taken['reason']}")
    else:
        slack_lines.append("Ação: nenhuma — Claude decidiu não reiniciar nada.")

    notify_slack("\n".join(slack_lines))

    if action_taken and action_taken["result"].get("ok") and not dry_run:
        resolve_pagerduty_incident(incident_id)

    if action_taken and not action_taken["result"].get("ok"):
        return 1
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--payload-file",
        help="Arquivo JSON com um payload de incidente simulado (teste local, sem PagerDuty real).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Não executa kubectl de verdade nem resolve o incidente — só loga o que faria.",
    )
    args = parser.parse_args()

    if args.payload_file:
        with open(args.payload_file, "r", encoding="utf-8") as f:
            payload = json.load(f)
    else:
        raw = os.environ.get("INCIDENT_PAYLOAD")
        if not raw:
            print("Erro: forneça --payload-file ou a env var INCIDENT_PAYLOAD.", file=sys.stderr)
            return 2
        payload = json.loads(raw)

    return run_agent(payload, dry_run=args.dry_run)


if __name__ == "__main__":
    sys.exit(main())
