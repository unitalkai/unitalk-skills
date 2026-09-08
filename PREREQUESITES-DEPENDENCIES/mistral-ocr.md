# Mistral OCR Skill — Prerequisites & Dependencies

Cloud OCR via Hermes-web → LiteLLM (`mistral/mistral-ocr-latest`). **No pip, npm, or apt packages** are installed by `setup.sh` for this skill.

## Runtime Dependencies (Hermes-web deployment)

| Variable | Where | Purpose |
|----------|-------|---------|
| `NEXT_PUBLIC_APP_URL` | Hermes-web | Public app URL; agent calls `{APP_URL}/api/ocr` |
| `UNITALK_LITELLM_GATEWAY_KEY` | Hermes-web (server) | LiteLLM bearer for `/v1/ocr` (preferred) |
| `UNITALK_LITELLM_GATEWAY_URL` | Hermes-web (optional) | LiteLLM origin; defaults to `https://llmgateway.unitalk.ai` |
| Gateway `baseUrl` + `token` | Agent session | Required in each `/api/ocr` request body (connection validation) |

Fallback: if `UNITALK_LITELLM_GATEWAY_KEY` is unset, Hermes-web may use `NEXT_PUBLIC_UNITALK_GATEWAY_KEY` server-side.

## LiteLLM / Gateway

| Requirement | Notes |
|-------------|-------|
| `/v1/ocr` endpoint | Must accept `mistral/mistral-ocr-latest` |
| Document input | `document_url` or `image_url` must be fetchable by LiteLLM |

## Python / Node / OS

None for the default Unitalk path.

Optional local fallback (not this skill): `setup.sh --all` installs `tesseract-ocr` + `pytesseract` for the `pdf` skill’s legacy local OCR path.

## Provisioning

- Skill directory: `documents-and-analysis/mistral-ocr/` (copied to `/opt/data/skills` by `setup.sh`)
- Hermes-web auto-enables skill name `mistral-ocr` on connect when the gateway lists it

## Quick Reference

```bash
# Agent-side (example) — Hermes-web proxies to LiteLLM with server key
curl -sS -X POST "${NEXT_PUBLIC_APP_URL}/api/ocr" \
  -H "Content-Type: application/json" \
  -d '{"baseUrl":"https://gw.agent.unitalk.ai","token":"<session>","documentUrl":"https://example.com/scan.pdf"}'
```
