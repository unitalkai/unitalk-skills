# Hermes Skills

A curated collection of agent skills for the [Hermes](https://github.com/the-hermes-project) agent platform, providing document creation, editing, and analysis capabilities for common office file formats.

## Repository Structure

```
hermes-skills/
├── setup.sh                          # One-shot provisioning script
├── README.md                         # This file
├── PREREQUESITES-DEPENDENCIES/       # Per-skill dependency manifests
│   ├── docx.md
│   ├── pdf.md
│   ├── pptx.md
│   └── xlsx.md
├── docx-odt/                         # Word / ODT skill
│   ├── SKILL.md                      # Skill definition & usage guide
│   ├── LICENSE.txt
│   ├── scripts/                      # Python helper scripts
│   │   ├── accept_changes.py
│   │   ├── comment.py
│   │   ├── office/                   # Shared office-format tooling
│   │   │   ├── pack.py               #   Repack exploded XML → .docx/.pptx/.xlsx
│   │   │   ├── unpack.py             #   Unzip .docx/.pptx/.xlsx → XML tree
│   │   │   ├── soffice.py            #   LibreOffice headless bridge
│   │   │   ├── validate.py           #   XSD schema validation
│   │   │   ├── helpers/              #   XML merge-runs, redline simplification
│   │   │   ├── schemas/              #   ECMA / ISO-IEC 29500 XSD schemas
│   │   │   └── validators/           #   Per-format validators (docx, pptx, redlining)
│   │   └── templates/                #   XML templates for comments, people, etc.
├── pdf/                              # PDF skill
│   ├── SKILL.md
│   ├── forms.md                      # Form-filling reference
│   ├── reference.md                  # General PDF reference
│   ├── LICENSE.txt
│   └── scripts/
│       ├── check_bounding_boxes.py
│       ├── check_fillable_fields.py
│       ├── convert_pdf_to_images.py
│       ├── create_validation_image.py
│       ├── extract_form_field_info.py
│       ├── extract_form_structure.py
│       ├── fill_fillable_fields.py
│       └── fill_pdf_form_with_annotations.py
├── pptx/                             # PowerPoint skill
│   ├── SKILL.md
│   ├── editing.md                    # Editing & QA reference
│   ├── pptxgenjs.md                  # pptxgenjs (Node.js) usage guide
│   ├── LICENSE.txt
│   └── scripts/
│       ├── add_slide.py
│       ├── clean.py
│       ├── thumbnail.py
│       └── office/                   # (shared structure — see docx-odt/scripts/office/)
└── xlsx-ods/                         # Excel / ODS skill
    ├── SKILL.md
    ├── LICENSE.txt
    └── scripts/
        ├── recalc.py
        └── office/                   # (shared structure — see docx-odt/scripts/office/)
```

### Skills at a Glance

| Skill        | Directory   | Formats                                  | Key Capabilities                                                                                                                                |
| ------------ | ----------- | ---------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| **docx-odt** | `docx-odt/` | `.docx`, `.odt`, `.doc`, `.txt`          | Create/edit Word & ODT documents, tracked changes, comments, find-and-replace, image insertion, format conversion (doc→docx, odt↔docx, txt→odt) |
| **pdf**      | `pdf/`      | `.pdf`                                   | Merge, split, rotate, encrypt/decrypt, fill forms, extract text/tables/images, OCR, create new PDFs from scratch                                |
| **pptx**     | `pptx/`     | `.pptx`                                  | Create/edit presentations, slide thumbnails, text extraction, template-based generation, programmatic creation via pptxgenjs                    |
| **xlsx-ods** | `xlsx-ods/` | `.xlsx`, `.xlsm`, `.ods`, `.csv`, `.tsv` | Read/write/edit spreadsheets, formula recalculation, data cleaning, charting, format conversion (ods↔xlsx)                                      |

---

## Deployment

The skills are designed to be deployed alongside a Hermes agent instance. The recommended approach is to run `setup.sh` inside the Hermes Docker container.

### Prerequisites

- A running Hermes container with:
  - `/opt/hermes/.venv/` — Python virtual environment (created by the Hermes installer)
  - `/opt/data/skills/` — skills directory mounted or baked into the image
- `setup.sh` and all skill directories available inside the container (via bind mount, `COPY`, or `git clone`)

### One-Shot Setup (Recommended)

Copy `setup.sh` and the skill directories into the container, then run:

```bash
# Inside the Hermes container (as root):
./setup.sh

# Or with optional/legacy dependencies:
./setup.sh --all
```

The script performs the following steps in order:

1. **Pre-flight checks** — verifies root access and that all four skill directories exist
2. **Copy skills** — copies `docx-odt/`, `pdf/`, `pptx/`, and `xlsx-ods/` into `/opt/data/skills/`, replacing only those four directories (other pre-existing skills are left untouched)
3. **Bootstrap pip** — runs `python -m ensurepip --default-pip` inside the Hermes venv if pip isn't already available
4. **OS packages** — installs `pandoc`, `libreoffice-core`, `libreoffice-impress`, `poppler-utils`, `gcc`, `qpdf`, and `imagemagick` via `apt-get`
5. **Python packages** — installs all required libraries into **both** the Hermes venv **and** the system Python (so that bare `python -m markitdown` works)
6. **Node.js global packages** — installs `docx`, `pptxgenjs`, `react-icons`, `react`, `react-dom`, and `sharp` via `npm install -g` (skipped gracefully if Node.js is not present)
7. **Verification** — checks that all critical binaries are on `$PATH` and all key Python modules are importable

### Dockerfile Example

```dockerfile
FROM hermes-base:latest

# Copy skills into the image
COPY hermes-skills/ /tmp/hermes-skills/

# Run the setup script
RUN cd /tmp/hermes-skills && bash setup.sh && rm -rf /tmp/hermes-skills
```

Or, if you prefer to keep skills on a volume/bind mount and provision at container start:

```dockerfile
FROM hermes-base:latest

COPY hermes-skills/setup.sh /usr/local/bin/hermes-skills-setup
COPY hermes-skills/ /opt/hermes-skills-src/

# The entrypoint can run setup.sh if /opt/data/skills is empty
COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]
```

Example `docker-entrypoint.sh`:

```bash
#!/usr/bin/env bash
# Only run setup if skills haven't been provisioned yet
if [ ! -d /opt/data/skills/docx-odt ]; then
    cd /opt/hermes-skills-src && bash setup.sh
fi
exec "$@"
```

### Docker Compose Example

```yaml
services:
  hermes:
    image: hermes:latest
    volumes:
      - ./hermes-skills:/tmp/hermes-skills:ro
      - skills_data:/opt/data/skills
    command: >
      bash -c "
        if [ ! -d /opt/data/skills/docx-odt ]; then
          cd /tmp/hermes-skills && bash setup.sh
        fi &&
        exec /opt/hermes/bin/hermes-server
      "

volumes:
  skills_data:
```

### What Gets Installed

See `PREREQUESITES-DEPENDENCIES/` for the full per-skill breakdown. Quick summary:

| Category                      | Packages                                                                                                                 |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| **OS (apt)**                  | `pandoc`, `libreoffice-core`, `libreoffice-impress`, `poppler-utils`, `gcc`, `qpdf`, `imagemagick`                       |
| **OS optional** (`--all`)     | `tesseract-ocr`, `pdftk-java`                                                                                            |
| **Python**                    | `defusedxml`, `lxml`, `pypdf`, `pdfplumber`, `pdf2image`, `Pillow`, `reportlab`, `pandas`, `markitdown[all]`, `openpyxl` |
| **Python optional** (`--all`) | `pytesseract`, `pypdfium2`, `numpy`                                                                                      |
| **npm global**                | `docx`, `pptxgenjs`, `react-icons`, `react`, `react-dom`, `sharp`                                                        |

### Why System Python Too?

The Hermes venv at `/opt/hermes/.venv/bin/python` is used by scripts that explicitly reference it. However, agents often invoke commands like `python -m markitdown file.pptx` using the bare `python` on `$PATH` (the system Python). To ensure both work, `setup.sh` installs Python packages into **both** the venv and the system Python.

---

## Manual Setup (Without setup.sh)

If you prefer to install dependencies manually, consult the per-skill manifests:

```bash
# OS packages
sudo apt-get install -y pandoc libreoffice-core libreoffice-impress poppler-utils gcc qpdf imagemagick

# Python (into the Hermes venv)
/opt/hermes/.venv/bin/pip install defusedxml lxml pypdf pdfplumber pdf2image Pillow reportlab pandas "markitdown[all]" openpyxl

# Python (into system Python, for bare `python` commands)
pip3 install defusedxml lxml pypdf pdfplumber pdf2image Pillow reportlab pandas "markitdown[all]" openpyxl

# Node.js (if available)
npm install -g docx pptxgenjs react-icons react react-dom sharp
```

---

## License

Each skill carries its own license — see the `LICENSE.txt` file inside each skill directory.
