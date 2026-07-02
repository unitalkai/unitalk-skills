# XLSX Skill — Prerequisites & Dependencies

## Python Libraries

These must be installed in the Python environment used to run the skill's scripts:

| Library      | Version      | Used By                                                                                          | Purpose                                                      |
| ------------ | ------------ | ------------------------------------------------------------------------------------------------ | ------------------------------------------------------------ |
| `openpyxl`   | (any recent) | `recalc.py`, SKILL.md (code snippets)                                                            | Read/write .xlsx files with formulas, formatting, styles     |
| `defusedxml` | (any recent) | `unpack.py`, `pack.py`, `merge_runs.py`, `simplify_redlines.py`, `base.py`, `docx.py`, `pptx.py` | Safe XML parsing (prevents billion laughs / XXE attacks)     |
| `lxml`       | (any recent) | `base.py`, `docx.py`, `pptx.py`                                                                  | XSD schema validation and namespace-aware XML parsing        |
| `pandas`     | (any recent) | SKILL.md (code snippets)                                                                         | Data analysis, bulk operations, reading/writing tabular data |

Install with:

```bash
pip install openpyxl defusedxml lxml pandas
```

## NPM / Node.js Libraries

No Node.js libraries are required for the XLSX skill.

## Operating System / Binary Dependencies

These must be available on `$PATH`:

| Binary     | Package (Debian/Ubuntu)               | Package (macOS)    | Used By                         | Purpose                                                                                                                                           |
| ---------- | ------------------------------------- | ------------------ | ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `soffice`  | `libreoffice-core` (or `libreoffice`) | `libreoffice`      | `recalc.py`, `soffice.py`       | Recalculates Excel formulas via headless LibreOffice macro. Required for all formula-bearing .xlsx files.                                         |
| `gcc`      | `build-essential` (or `gcc`)          | `gcc` (Xcode CLT)  | `soffice.py` (`_ensure_shim()`) | Compiles an `LD_PRELOAD` shim (`.so`) at runtime when AF_UNIX sockets are blocked (sandboxed VMs). Only used on-demand, not for normal operation. |
| `timeout`  | `coreutils` (built-in)                | `coreutils` (brew) | `recalc.py`                     | Limits LibreOffice recalculation runtime (Linux). Part of GNU coreutils.                                                                          |
| `gtimeout` | —                                     | `coreutils` (brew) | `recalc.py`                     | Limits LibreOffice recalculation runtime (macOS). Installed via `brew install coreutils`.                                                         |

Install on Debian/Ubuntu:

```bash
sudo apt-get install libreoffice-core gcc
```

Install on macOS:

```bash
brew install libreoffice gcc coreutils
```

> **Note:** `timeout` is built-in on Linux (part of GNU coreutils). On macOS, install `coreutils` via Homebrew to get `gtimeout`.

## Python Standard Library (no installation needed)

These modules are used across the skill's scripts and come bundled with Python 3:

| Module                  | Used By                                                                                                                              |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `json`                  | `recalc.py`                                                                                                                          |
| `os`                    | `recalc.py`, `soffice.py`                                                                                                            |
| `platform`              | `recalc.py`                                                                                                                          |
| `subprocess`            | `recalc.py`, `soffice.py`, `redlining.py`                                                                                            |
| `sys`                   | `recalc.py`, `unpack.py`, `pack.py`, `validate.py`, `soffice.py`                                                                     |
| `pathlib`               | `recalc.py`, `unpack.py`, `pack.py`, `soffice.py`, `base.py`, `merge_runs.py`, `simplify_redlines.py`, `redlining.py`, `validate.py` |
| `argparse`              | `unpack.py`, `pack.py`, `validate.py`                                                                                                |
| `shutil`                | `pack.py`                                                                                                                            |
| `tempfile`              | `pack.py`, `soffice.py`, `validate.py`, `redlining.py`                                                                               |
| `zipfile`               | `unpack.py`, `pack.py`, `validate.py`, `redlining.py`, `simplify_redlines.py`                                                        |
| `xml.etree.ElementTree` | `simplify_redlines.py`, `redlining.py`                                                                                               |
| `re`                    | `base.py`, `pptx.py`                                                                                                                 |
| `socket`                | `soffice.py`                                                                                                                         |

## Quick Install — All at Once

```bash
# Debian/Ubuntu
sudo apt-get install -y libreoffice-core gcc
pip install openpyxl defusedxml lxml pandas

# macOS
brew install libreoffice gcc coreutils
pip install openpyxl defusedxml lxml pandas
```
