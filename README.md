# Unitalk Skills

A curated collection of 19 agent skills organized into 6 category directories for the Unitalk agent platform.

## Repository Structure

```
unitalk-skills/
├── setup.sh                          # One-shot provisioning script
├── README.md                         # This file
├── PREREQUESITES-DEPENDENCIES/       # Per-skill dependency manifests
│   ├── docx.md
│   ├── pdf.md
│   ├── pptx.md
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
│   ├── docx-odt/
│   ├── jupyter-live-kernel/
│   ├── nano-pdf/
│   ├── pdf/
│   ├── pptx/
│   └── xlsx-ods/
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
| **docx-odt**          | `documents-and-analysis/docx-odt/`          | Create/edit Word & ODT documents, tracked changes, comments, find-and-replace, image insertion, format conversion (doc→docx, odt↔docx, txt→odt) |
| **jupyter-live-kernel** | `documents-and-analysis/jupyter-live-kernel/` | Iterative Python via live Jupyter kernel, data exploration, visualization, persistent state                                                   |
| **nano-pdf**          | `documents-and-analysis/nano-pdf/`          | Natural-language PDF text editing (typos, titles) via nano-pdf CLI                                                                              |
| **pdf**               | `documents-and-analysis/pdf/`               | Merge, split, rotate, encrypt/decrypt, fill forms, extract text/tables/images, OCR, create new PDFs                                             |
| **pptx**              | `documents-and-analysis/pptx/`              | Create/edit presentations, slide thumbnails, text extraction, template-based generation, programmatic creation via pptxgenjs                    |
| **xlsx-ods**          | `documents-and-analysis/xlsx-ods/`          | Read/write/edit spreadsheets, formula recalculation, data cleaning, charting, format conversion (ods↔xlsx)                                      |

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
  - `/opt/data/skills/` — skills directory
- `setup.sh` and all skill directories available inside the container

### One-Shot Setup (Recommended)

```bash
# Inside the container (as root):
./setup.sh

# Or with optional dependencies:
./setup.sh --all
```

The script performs:
1. **Pre-flight checks** — verifies root access and required directories
2. **Copy skills** — copies all category directories into `/opt/data/skills/`
3. **Bootstrap pip** — ensures pip is available in the venv
4. **OS packages** — installs system dependencies via `apt-get`
5. **Python packages** — installs required libraries into both the venv and system Python
6. **Node.js global packages** — installs npm packages (skipped if Node.js unavailable)
7. **Verification** — checks critical binaries and Python modules

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

The Unitalk venv at `/opt/hermes/.venv/bin/python` is used by scripts that explicitly reference it. However, agents often invoke commands like `python -m markitdown file.pptx` using the bare `python` on `$PATH`. To ensure both work, `setup.sh` installs Python packages into **both** the venv and the system Python.

---

## Manual Setup

```bash
# OS packages
sudo apt-get install -y pandoc libreoffice-core libreoffice-impress poppler-utils gcc qpdf imagemagick

# Python (into the venv)
/opt/hermes/.venv/bin/pip install defusedxml lxml pypdf pdfplumber pdf2image Pillow reportlab pandas "markitdown[all]" openpyxl

# Python (into system Python)
pip3 install defusedxml lxml pypdf pdfplumber pdf2image Pillow reportlab pandas "markitdown[all]" openpyxl

# Node.js (if available)
npm install -g docx pptxgenjs react-icons react react-dom sharp
```

---

## License

Each skill carries its own license — see the `LICENSE.txt` or `LICENSE` file inside each skill directory.