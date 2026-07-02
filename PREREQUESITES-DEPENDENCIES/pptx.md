# PPTX Skill — Prerequisites & Dependencies

## Python Libraries

| Library        | Used By                                                                                                                                                                       | Purpose                                                             |
| -------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| `defusedxml`   | `unpack.py`, `pack.py`, `clean.py`, `add_slide.py`, `thumbnail.py`, `merge_runs.py`, `simplify_redlines.py`, `validators/base.py`, `validators/docx.py`, `validators/pptx.py` | Safe XML parsing (prevents billion laughs / XXE attacks)            |
| `lxml`         | `validators/base.py`, `validators/pptx.py`, `validators/docx.py`                                                                                                              | Advanced XML parsing & XSD schema validation                        |
| `Pillow` (PIL) | `thumbnail.py`                                                                                                                                                                | Slide thumbnail grid generation (image compositing, drawing, fonts) |
| `markitdown`   | Referenced in `SKILL.md`, `editing.md`                                                                                                                                        | Text extraction from `.pptx` files via `python -m markitdown`       |

### Install (pip)

```bash
pip install defusedxml lxml Pillow markitdown
```

## OS-Level Dependencies

| Dependency              | Used By                                  | Purpose                                                                                      |
| ----------------------- | ---------------------------------------- | -------------------------------------------------------------------------------------------- |
| `soffice` (LibreOffice) | `soffice.py`, referenced in `editing.md` | Converts slides to images for visual analysis and QA                                         |
| `gcc`                   | `soffice.py`                             | Compiles an `LD_PRELOAD` shim for sandboxed environments where `AF_UNIX` sockets are blocked |
| `pdftoppm`              | Referenced in `editing.md`               | Converts PDFs to individual slide images for full-resolution visual QA (used with `soffice`) |

### Install

```bash
# Debian/Ubuntu
sudo apt install libreoffice-core libreoffice-impress gcc poppler-utils

# RHEL/Fedora
sudo dnf install libreoffice-core libreoffice-impress gcc poppler-utils
```

> **Note:** `pdftoppm` is part of the `poppler-utils` package.

## Node.js Dependencies (pptxgenjs — creating presentations from scratch)

Required when creating `.pptx` files programmatically without a template.

| Package       | Purpose                                                                                |
| ------------- | -------------------------------------------------------------------------------------- |
| `pptxgenjs`   | Core library for creating PowerPoint files programmatically                            |
| `react-icons` | Icon library providing Font Awesome, Material Design, Heroicons, Bootstrap Icons, etc. |
| `react`       | React runtime (required by `react-icons` for SVG rendering)                            |
| `react-dom`   | React DOM server (used via `ReactDOMServer.renderToStaticMarkup` for icon → SVG)       |
| `sharp`       | Converts SVG icons to PNG for embedding in slides                                      |

### Install (npm)

```bash
npm install -g pptxgenjs react-icons react react-dom sharp
```
