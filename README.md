# Unitalk Skills

A curated collection of 20 agent skills organized into 6 category directories for the Unitalk agent platform.

## Repository Structure

```
unitalk-skills/
├── setup.sh                          # One-shot provisioning script
├── update-skill.sh                   # Explicit selected-skill updater
├── README.md                         # This file
├── PREREQUESITES-DEPENDENCIES/       # Per-skill dependency manifests
│   ├── docx.md
│   ├── mistral-ocr.md
│   ├── pdf.md
│   ├── powerpoint.md
│   └── xlsx.md
├── code/                             # Planning & automation skills
│   ├── DESCRIPTION.md
│   ├── computer-use/
│   ├── plan/
│   └── writing-plans/
├── discussion-and-writing/           # Writing & communication skills
│   ├── DESCRIPTION.md
│   ├── himalaya/
│   ├── humanizer/
│   ├── ideation/
│   └── obsidian/
├── documents-and-analysis/           # Document & data analysis skills
│   ├── DESCRIPTION.md
│   ├── data-analysis/
│   ├── docx/
│   ├── jupyter-live-kernel/
│   ├── mistral-ocr/
│   ├── nano-pdf/
│   ├── pdf/
│   ├── powerpoint/
│   └── xlsx/
├── medias/                           # Media creation skills
│   ├── DESCRIPTION.md
│   ├── excalidraw/
│   └── youtube-content/
├── optimization-and-security/        # Optimization & efficiency skills
│   ├── DESCRIPTION.md
│   └── caveman/
└── web-and-research/                 # Web & research skills
    ├── DESCRIPTION.md
    ├── arxiv/
    ├── blogwatcher/
    ├── llm-wiki/
    ├── maps/
    └── xurl/
```

## Skills at a Glance

### Code & Automation

| Skill              | Directory                            | Key Capabilities                                                          |
| ------------------ | ------------------------------------ | ------------------------------------------------------------------------- |
| **computer-use**   | `code/computer-use/`                 | Desktop automation, multi-platform interactions                           |
| **plan**           | `code/plan/`                         | Plan-mode workflows, task decomposition                                   |
| **writing-plans**  | `code/writing-plans/`                | Implementation plan writing, structured technical specifications          |

### Discussion & Writing

| Skill              | Directory                            | Key Capabilities                                                          |
| ------------------ | ------------------------------------ | ------------------------------------------------------------------------- |
| **himalaya**       | `discussion-and-writing/himalaya/`   | Email CLI management, message composition, account configuration          |
| **humanizer**      | `discussion-and-writing/humanizer/`  | AI text humanization, style transformation                                |
| **ideation**       | `discussion-and-writing/ideation/`   | Creative brainstorming, project ideation, prompt library                  |
| **obsidian**       | `discussion-and-writing/obsidian/`   | Obsidian vault management, note creation and editing                      |

### Documents & Analysis

| Skill                 | Directory                                   | Key Capabilities                                                                                                                                |
| --------------------- | ------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| **data-analysis**     | `documents-and-analysis/data-analysis/`     | Full-cycle data analysis, visualization, HTML reports                                                                                          |
| **docx**              | `documents-and-analysis/docx/`              | Create/read/edit/template Word `.docx` via python-docx CLIs (revisions, comments, validation)                                                  |
| **jupyter-live-kernel** | `documents-and-analysis/jupyter-live-kernel/` | Iterative Python via live Jupyter kernel, data exploration, visualization, persistent state                                                   |
| **mistral-ocr**         | `documents-and-analysis/mistral-ocr/`         | Scanned PDF / image OCR via Hermes-web `POST /api/ocr` (Mistral via LiteLLM)                                                                    |
| **nano-pdf**          | `documents-and-analysis/nano-pdf/`          | Natural-language PDF text editing (typos, titles) via nano-pdf CLI                                                                              |
| **pdf**               | `documents-and-analysis/pdf/`               | Create/merge/split/forms/secure/stamp PDFs; text/table extraction; page images                                                                  |
| **powerpoint**        | `documents-and-analysis/powerpoint/`        | Create/read/edit/template/render `.pptx` via python-pptx CLIs                                                                                   |
| **xlsx**              | `documents-and-analysis/xlsx/`              | Create/read/edit/restructure Excel `.xlsx`, formula recalc, CSV interop                                                                         |

### Media

| Skill                 | Directory                     | Key Capabilities                                                          |
| --------------------- | ----------------------------- | ------------------------------------------------------------------------- |
| **excalidraw**        | `medias/excalidraw/`          | Hand-drawn diagrams, flowcharts, architecture diagrams, sequence diagrams |
| **youtube-content**   | `medias/youtube-content/`     | YouTube transcript extraction, summaries, threads, blog posts             |

### Optimization & Security

| Skill              | Directory                            | Key Capabilities                                                          |
| ------------------ | ------------------------------------ | ------------------------------------------------------------------------- |
| **caveman**        | `optimization-and-security/caveman/`  | Ultra-compressed communication mode, token optimization                    |

### Web & Research

| Skill              | Directory                            | Key Capabilities                                                          |
| ------------------ | ------------------------------------ | ------------------------------------------------------------------------- |
| **arxiv**          | `web-and-research/arxiv/`            | arXiv paper search and discovery                                          |
| **blogwatcher**    | `web-and-research/blogwatcher/`      | Blog/RSS feed monitoring and aggregation                                  |
| **llm-wiki**       | `web-and-research/llm-wiki/`         | Knowledge base / wiki builder from LLM output                             |
| **maps**           | `web-and-research/maps/`             | Geocoding, POI lookup, routing via OpenStreetMap/OSRM                     |
| **xurl**           | `web-and-research/xurl/`             | X/Twitter API integration, timeline and media management                  |

---

## Deployment

The skills are designed to be deployed alongside a Unitalk agent instance. The recommended approach is to run `setup.sh` inside the Unitalk container.

### Prerequisites

- A running Unitalk container with:
  - `/opt/hermes/.venv/` — Python virtual environment
  - `/opt/data/skills/` — persistent Hermes skills directory
- The provisioning scripts and all skill directories available inside the container

### One-Shot Setup (Recommended)

```bash
# Inside the container (as root):
./setup.sh

# Or with optional dependencies:
./setup.sh --all
```

The script performs:
1. **Pre-flight checks** — verifies root access and required directories
2. **Opt out of Hermes bundled-skill seeding** — prevents defaults from being restored on later starts
3. **Remove pristine bundled skills** — uses Hermes's `.bundled_manifest`; modified and custom skills are preserved
4. **Add missing repository skills** — copies each absent repository skill into `/opt/data/skills/<category>/<skill>`
5. **Bootstrap pip** — ensures pip is available in the venv
6. **Install dependencies** — installs required OS, Python, and global npm packages
7. **Verification** — checks critical binaries and Python modules

`setup.sh` is intentionally additive. If a target skill directory already exists, the script leaves it unchanged, whether it is a repository skill, a locally modified skill, or a custom user skill. Rerunning setup therefore installs newly published skills but does not update existing ones.

The entire `/opt/data` directory must be stored on a per-user persistent Docker volume. This preserves custom skills, installed repository skills, Hermes's bundled-skill opt-out marker, configuration, and update backups when a container is replaced.

After changing the installed skill set, restart the Hermes gateway (or run `/reload-skills` in an active session) so long-running processes refresh their skill index.

### Updating Selected Skills

Because setup never overwrites an existing skill, use `update-skill.sh` when you intentionally want to publish a newer repository version of one or more skills.

Pass each skill as its repository-relative `<category>/<skill>` path:

```bash
# Update one skill
./update-skill.sh code/plan

# Update several skills as one batch
./update-skill.sh code/plan documents-and-analysis/pdf
```

The updater:

1. Validates and stages every requested repository skill before changing installed files.
2. Verifies that an existing target declares the same skill name as the repository version.
3. Saves existing targets in one timestamped batch under `/opt/data/skill-update-backups/`.
4. Replaces only the explicitly requested paths.
5. Installs a requested skill if its target is currently missing.
6. Rolls back the entire batch if any requested update fails.
7. Assigns the published skills to `hermes:hermes`.

If an existing target path contains a differently named skill, the updater aborts to avoid replacing a custom skill accidentally. Use `--force` only after verifying that the exact path should be replaced:

```bash
./update-skill.sh --force code/plan
```

Successful output includes the persistent backup batch path:

```text
Hermes skill update complete!
Updated: 2
Backup batch: /opt/data/skill-update-backups/20260916T133331Z.G0nmgT
```

After an update, restart Hermes or run `/reload-skills` so active processes refresh their skill index.

### What Gets Installed

See `PREREQUESITES-DEPENDENCIES/` for the full per-skill breakdown. Quick summary:

| Category                      | Packages                                                                                                                 |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| **OS (apt)**                  | `pandoc`, `libreoffice-core`, `libreoffice-impress`, `poppler-utils`, `gcc`, `qpdf`, `imagemagick`                       |
| **OS optional** (`--all`)     | `tesseract-ocr`, `pdftk-java`                                                                                            |
| **Python**                    | `defusedxml`, `lxml`, `python-docx`, `pypdf`, `pdfplumber`, `pdf2image`, `Pillow`, `reportlab`, `pypdfium2`, `nano-pdf`, `pandas`, `markitdown[all]`, `python-pptx`, `openpyxl` |
| **Python optional** (`--all`) | `pytesseract`, `numpy`                                                                                                                                                        |
| **npm global**                | `docx`, `pptxgenjs`, `react-icons`, `react`, `react-dom`, `sharp`                                                                                                              |

**Mistral OCR** (`mistral-ocr` skill) uses Hermes-web `/api/ocr` — not pip/npm. See `PREREQUESITES-DEPENDENCIES/mistral-ocr.md`.

### Why System Python Too?

The Unitalk venv at `/opt/hermes/.venv/bin/python` is used by scripts that explicitly reference it. However, agents often invoke commands like `python -m markitdown file.pptx` using the bare `python` on `$PATH`. To ensure both work, `setup.sh` installs Python packages into **both** the venv and the system Python.

---

## Manual Setup

```bash
# OS packages
sudo apt-get install -y pandoc libreoffice-core libreoffice-impress poppler-utils gcc qpdf imagemagick

# Python (into the venv)
/opt/hermes/.venv/bin/pip install defusedxml lxml python-docx pypdf pdfplumber pdf2image Pillow reportlab pypdfium2 nano-pdf pandas "markitdown[all]" python-pptx openpyxl

# Python (into system Python)
pip3 install defusedxml lxml python-docx pypdf pdfplumber pdf2image Pillow reportlab pypdfium2 nano-pdf pandas "markitdown[all]" python-pptx openpyxl

# Node.js (if available)
npm install -g docx pptxgenjs react-icons react react-dom sharp
```

---

## License

Each skill carries its own license — see the `LICENSE.txt` or `LICENSE` file inside each skill directory.
