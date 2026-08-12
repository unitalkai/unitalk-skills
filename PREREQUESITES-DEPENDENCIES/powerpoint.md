# PowerPoint Skill — Prerequisites & Dependencies

Clean-room Hermes skill at `documents-and-analysis/powerpoint/`.

## Python Libraries

| Library       | Purpose                                      |
| ------------- | -------------------------------------------- |
| `python-pptx` | Create, read, and edit `.pptx` via CLI scripts |

```bash
pip install python-pptx
```

`setup.sh` also still installs `markitdown[all]` (harmless leftover from the old pptx skill).

## OS binaries

| Binary     | Package           | Purpose                                      |
| ---------- | ----------------- | -------------------------------------------- |
| `soffice`  | `libreoffice-impress` / `libreoffice-core` | Deck → PDF for `pptx_render.py` / export |
| `pdftoppm` | `poppler-utils`   | PDF → slide PNGs                             |

## Not required for this skill

npm `pptxgenjs` / `react` / `sharp` — kept in `setup.sh` for backward compatibility but unused by the current powerpoint CLIs.
