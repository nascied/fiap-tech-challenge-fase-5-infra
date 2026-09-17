"""Ponte PagerDuty -> GitHub Actions (self-healing, ver aiops/README.md).

Único trabalho desta função: receber o webhook V3 do PagerDuty
(incident.triggered), verificar a assinatura, e repassar o payload cru pra um
repository_dispatch no GitHub — toda a análise/decisão fica no workflow
`.github/workflows/incident-response.yml` (aiops/incident_response.py), não
aqui. Mantida deliberadamente simples: só stdlib (urllib), sem dependências
externas, pra não precisar de layer/pacote zipado com libs.

Formato de assinatura (header `x-pagerduty-signature`) assumido como
HMAC-SHA256 hex, prefixo "v1=", possivelmente múltiplos valores separados por
vírgula (rotação de secret) — NÃO confirmado ao vivo contra a documentação
oficial do PagerDuty nesta sessão (doc renderizada via JS, WebFetch não
extraiu o conteúdo). Confirmar com um "test webhook" real do PagerDuty antes
de depender disso em produção. Ver aiops/README.md.
"""

import hashlib
import hmac
import json
import os
import urllib.error
import urllib.request

GITHUB_API_VERSION = "2022-11-28"
DISPATCH_EVENT_TYPE = "pagerduty-incident"


def _verify_signature(raw_body: bytes, signature_header: str | None, secret: str) -> bool:
    if not signature_header:
        return False
    computed = hmac.new(secret.encode("utf-8"), raw_body, hashlib.sha256).hexdigest()
    for candidate in signature_header.split(","):
        candidate = candidate.strip()
        if candidate.startswith("v1="):
            candidate = candidate[len("v1="):]
        if hmac.compare_digest(candidate, computed):
            return True
    return False


def _dispatch_to_github(payload: dict, github_repo: str, github_token: str) -> tuple[int, str]:
    url = f"https://api.github.com/repos/{github_repo}/dispatches"
    body = json.dumps(
        {
            "event_type": DISPATCH_EVENT_TYPE,
            "client_payload": {"pagerduty_event": payload},
        }
    ).encode("utf-8")

    req = urllib.request.Request(
        url,
        data=body,
        method="POST",
        headers={
            "Authorization": f"Bearer {github_token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": GITHUB_API_VERSION,
            "Content-Type": "application/json",
            "User-Agent": "solidarytech-incident-bridge",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return resp.status, resp.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read().decode("utf-8", errors="replace")


def _response(status: int, message: str) -> dict:
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"message": message}),
    }


def handler(event, context):  # noqa: D401 - assinatura exigida pelo Lambda runtime
    import base64

    headers = {k.lower(): v for k, v in (event.get("headers") or {}).items()}
    raw_body = event.get("body") or ""
    if event.get("isBase64Encoded"):
        raw_body_bytes = base64.b64decode(raw_body)
    else:
        raw_body_bytes = raw_body.encode("utf-8")

    secret = os.environ["PAGERDUTY_WEBHOOK_SECRET"]
    if not _verify_signature(raw_body_bytes, headers.get("x-pagerduty-signature"), secret):
        return _response(401, "assinatura inválida")

    try:
        payload = json.loads(raw_body_bytes)
    except json.JSONDecodeError:
        return _response(400, "body não é JSON válido")

    event_type = payload.get("event", {}).get("event_type")
    if event_type != "incident.triggered":
        # Não é o evento que nos interessa (ex.: acknowledged/resolved) — 2xx
        # pra não fazer o PagerDuty ficar retentando a entrega.
        return _response(200, f"ignorado (event_type={event_type})")

    github_repo = os.environ["GITHUB_REPO"]
    github_token = os.environ["GITHUB_TOKEN"]
    status, body = _dispatch_to_github(payload, github_repo, github_token)

    if status >= 300:
        return _response(502, f"falha ao disparar o GitHub Action: {status} {body}")
    return _response(200, "incidente encaminhado pro GitHub Actions")
