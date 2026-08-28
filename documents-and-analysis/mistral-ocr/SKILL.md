---
name: mistral-ocr
description: Extract text from scanned PDFs and images via Mistral OCR (Hermes-web → LiteLLM). Load when a PDF has no text layer, pdf_read reports likely_scanned_pages, or the user needs OCR on a document or image.
version: 1.0.0
author: Unitalk
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [ocr, pdf, documents, mistral, scanned, text-extraction]
    category: productivity
    related_skills: [pdf, docx, xlsx, powerpoint]
---

# Mistral OCR Skill

Cloud OCR for **scanned PDFs** and **images** using Mistral OCR (`mistral/mistral-ocr-latest`) through the Unitalk LiteLLM gateway. Hermes-web exposes `POST /api/ocr`; this skill tells you when and how to call it.

**No local OCR packages required** — do not install tesseract/marker-pdf for the default Unitalk path.

## When to Use

- `pdf_read.py --meta` reports `likely_scanned_pages` or `--text` returns empty strings on image-only pages.
- User uploads a scanned PDF, photo of a document, or screenshot that needs readable text.
- You need markdown text from a **fetchable** PDF or image URL (attachments, arXiv PDFs, hosted files).

## When NOT to Use

- PDFs with a normal text layer — use the `pdf` skill (`pdf_read.py --text`, `--tables`).
- Word/PowerPoint structure — use `docx` / `powerpoint` or `markitdown`.
- Natural-language edits to existing PDF text — use `nano-pdf`.
- Local-only files with no public URL — obtain a fetchable URL first (user attachment URL, upload, or ask the user).

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| Hermes-web deployed | Public `NEXT_PUBLIC_APP_URL` reachable from LiteLLM (for the agent to call `/api/ocr`) |
| LiteLLM OCR | Gateway catalog includes `mistral/mistral-ocr-latest` at `/v1/ocr` |
| Server key on Hermes-web | `UNITALK_LITELLM_GATEWAY_KEY` (LiteLLM bearer for OCR) |
| Gateway session | Active Hermes connection (`baseUrl` + `token`) — same pattern as voice transcribe |

Hermes-web auto-enables this skill on connect when it is provisioned on the gateway.

## API — `POST /api/ocr`

Call the **Hermes-web** app URL, not LiteLLM directly. LiteLLM credentials stay on the server.

**Endpoint:** `{NEXT_PUBLIC_APP_URL}/api/ocr`

**Body (JSON):**

| Field | Required | Description |
|-------|----------|-------------|
| `baseUrl` | Yes | Active gateway base URL (e.g. `https://…agent.unitalk.ai`) |
| `token` | Yes | Gateway session token (same as other Hermes-web gateway proxies) |
| `documentUrl` | One of URL fields | HTTPS URL to a PDF LiteLLM can download |
| `imageUrl` | One of URL fields | HTTPS URL to a PNG/JPEG page or scan |
| `pages` | No | Optional 0-based page indices (PDF only) |

Supply **either** `documentUrl` **or** `imageUrl`, not both.

**Success response:**

```json
{
  "ok": true,
  "text": "…joined markdown across pages…",
  "pages": [{ "index": 0, "markdown": "…" }],
  "model": "mistral/mistral-ocr-latest",
  "usageInfo": { "pages_processed": 3 }
}
```

**Error response:** `{ "ok": false, "error": "…" }` (e.g. `invalid_connection`, `documentUrl_or_imageUrl_required`, `ocr_not_configured`).

## How to Run

Use the `terminal` tool with `curl` (or an HTTP tool if available). Replace placeholders with the real app URL, gateway credentials, and document URL.

```bash
APP_URL="https://your-hermes-web.example.com"
GW_BASE="https://your-gateway.agent.unitalk.ai"
GW_TOKEN="your-gateway-session-token"
DOC_URL="https://example.com/scanned-report.pdf"

curl -sS -X POST "${APP_URL}/api/ocr" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg baseUrl "$GW_BASE" \
    --arg token "$GW_TOKEN" \
    --arg documentUrl "$DOC_URL" \
    '{baseUrl: $baseUrl, token: $token, documentUrl: $documentUrl}')"
```

**Single page image:**

```bash
curl -sS -X POST "${APP_URL}/api/ocr" \
  -H "Content-Type: application/json" \
  -d '{"baseUrl":"'"$GW_BASE"'","token":"'"$GW_TOKEN"'","imageUrl":"https://example.com/page1.png"}'
```

**Subset of PDF pages** (0-based indices):

```bash
curl -sS -X POST "${APP_URL}/api/ocr" \
  -H "Content-Type: application/json" \
  -d '{"baseUrl":"'"$GW_BASE"'","token":"'"$GW_TOKEN"'","documentUrl":"'"$DOC_URL"'","pages":[0,2]}'
```

Parse the JSON response; use `text` (or per-page `pages[].markdown`) as the extracted content.

## Workflow with the PDF Skill

1. `pdf_read.py file.pdf --meta` — if `likely_scanned_pages` is non-empty, do **not** treat empty `--text` as “no content”.
2. If the user attachment or file already has a **fetchable HTTPS URL**, call `/api/ocr` with `documentUrl`.
3. If you only have a local path, prefer the platform attachment URL. As a fallback, `pdf_page_image.py --pages <scanned> --dpi 300 --out-dir imgs/` exports PNGs for visual review; OCR still needs **hosted** `imageUrl` values unless the user provides URLs.
4. After OCR, continue with `pdf`, `docx`, `xlsx`, or summarization as needed.

## Pitfalls

- **URL required** — Mistral OCR fetches by URL; local paths are not accepted by `/api/ocr`.
- **LiteLLM must reach the URL** — private localhost links fail; use signed/public URLs.
- **Do not call LiteLLM `/v1/ocr` from the agent** — keys live on Hermes-web; always use `/api/ocr`.
- **Encrypted PDFs** — decrypt with `pdf_secure.py --decrypt` before OCR if the source file is password-protected (then use a URL to the decrypted copy).
- **Do not fabricate text** when OCR fails — report the error and show what you tried.

## Related Skills

- `pdf` — inspect, merge, split, forms; detects scanned pages and hands off here.
- `docx` / `xlsx` / `powerpoint` — rebuild or edit structured documents from extracted text.
- `nano-pdf` — NL text edits on PDFs that already have a text layer.
