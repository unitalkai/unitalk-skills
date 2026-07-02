# DOCX Skill — Prerequisites & Dependencies

## Python Libraries

These must be installed in the Python environment used to run the skill's scripts:

| Library      | Version      | Used By                                                                                             | Purpose                                                  |
| ------------ | ------------ | --------------------------------------------------------------------------------------------------- | -------------------------------------------------------- |
| `defusedxml` | (any recent) | `unpack.py`, `pack.py`, `comment.py`, `merge_runs.py`, `simplify_redlines.py`, `base.py`, `docx.py` | Safe XML parsing (prevents billion laughs / XXE attacks) |
| `lxml`       | (any recent) | `base.py`, `docx.py`                                                                                | XSD schema validation and namespace-aware XML parsing    |

Install with:

```bash
pip install defusedxml lxml
```

## NPM / Node.js Libraries

| Library | Install Command       | Used By                             | Purpose                                       |
| ------- | --------------------- | ----------------------------------- | --------------------------------------------- |
| `docx`  | `npm install -g docx` | SKILL.md (JavaScript code snippets) | Creating new .docx documents programmatically |

## Operating System / Binary Dependencies

These must be available on `$PATH`:

| Binary     | Package (Debian/Ubuntu)               | Package (macOS)   | Used By                                              | Purpose                                                                                                                                           |
| ---------- | ------------------------------------- | ----------------- | ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `pandoc`   | `pandoc`                              | `pandoc`          | SKILL.md commands                                    | Text extraction from .docx/.odt, format conversion (docx→md, odt→md, md→odt, txt→odt)                                                             |
| `soffice`  | `libreoffice-core` (or `libreoffice`) | `libreoffice`     | `soffice.py`, `accept_changes.py`, SKILL.md commands | .doc→.docx conversion, .docx→PDF conversion, .odt↔.docx round-trips, accepting tracked changes via macro                                          |
| `pdftoppm` | `poppler-utils`                       | `poppler`         | SKILL.md commands                                    | Converting PDF pages to JPEG images (for document previews)                                                                                       |
| `gcc`      | `build-essential` (or `gcc`)          | `gcc` (Xcode CLT) | `soffice.py` (`_ensure_shim()`)                      | Compiles an `LD_PRELOAD` shim (`.so`) at runtime when AF_UNIX sockets are blocked (sandboxed VMs). Only used on-demand, not for normal operation. |

Install on Debian/Ubuntu:

```bash
sudo apt-get install pandoc libreoffice poppler-utils gcc
```

Install on macOS:

```bash
brew install pandoc libreoffice poppler gcc
```

## Python Standard Library (no installation needed)

These modules are used across the skill's scripts and come bundled with Python 3:

- `argparse` — CLI argument parsing (`accept_changes.py`, `unpack.py`, `pack.py`, `validate.py`)
- `subprocess` — Running external binaries (`soffice.py`, `accept_changes.py`)
- `pathlib` — File path handling (all scripts)
- `zipfile` — ZIP archive read/write (`unpack.py`, `pack.py`)
- `tempfile` — Temporary directories (`soffice.py`, `pack.py`)
- `shutil` — File copy operations (`accept_changes.py`, `pack.py`)
- `xml.etree.ElementTree` — XML parsing (`simplify_redlines.py`, `redlining.py`)
- `re` — Regular expressions (`base.py`, `docx.py`)
- `os` — Environment variables, file system (`soffice.py`)
- `socket` — AF_UNIX socket detection (`soffice.py`)
- `logging` — Log output (`accept_changes.py`)
- `random` — Random ID generation (`comment.py`, `docx.py`)
- `datetime` — Timestamps for comments (`comment.py`)
- `sys` — System utilities (`unpack.py`, `pack.py`, `validate.py`)
