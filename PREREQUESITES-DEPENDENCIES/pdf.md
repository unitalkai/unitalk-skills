# PDF Skill — Required Dependencies

## Python Libraries

### Core (required for most operations)

| Library          | Usage                                                                                                                                                                                                                              | Install                  |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| **pypdf**        | Core PDF manipulation: merge, split, rotate, encrypt/decrypt, fill form fields, add annotations. Used by `check_fillable_fields.py`, `extract_form_field_info.py`, `fill_fillable_fields.py`, `fill_pdf_form_with_annotations.py`. | `pip install pypdf`      |
| **pdfplumber**   | Text and table extraction with layout preservation. Used by `extract_form_structure.py`.                                                                                                                                           | `pip install pdfplumber` |
| **pdf2image**    | Convert PDF pages to PNG images. Used by `convert_pdf_to_images.py`.                                                                                                                                                               | `pip install pdf2image`  |
| **Pillow** (PIL) | Image manipulation, drawing bounding-box validation overlays. Used by `create_validation_image.py`.                                                                                                                                | `pip install Pillow`     |
| **reportlab**    | Create new PDFs from scratch (Canvas, Platypus, tables, styled paragraphs).                                                                                                                                                        | `pip install reportlab`  |

### Optional / Advanced

| Library         | Usage                                                                                              | Install                   |
| --------------- | -------------------------------------------------------------------------------------------------- | ------------------------- |
| **pandas**      | Handling extracted tables and exporting to Excel/CSV.                                              | `pip install pandas`      |
| **pytesseract** | OCR on scanned/image-based PDFs to extract text.                                                   | `pip install pytesseract` |
| **pypdfium2**   | Alternative PDF rendering (faster image generation, text extraction). Mentioned in `reference.md`. | `pip install pypdfium2`   |
| **numpy**       | Numerical array processing for advanced image-based figure extraction.                             | `pip install numpy`       |

---

## Operating-System / System Tools

### Required

| Tool              | Package                                  | Usage                                                                                                                                                       |
| ----------------- | ---------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **poppler-utils** | `poppler-utils` (apt) / `poppler` (brew) | Provides `pdftotext` (text extraction), `pdfimages` (extract embedded images), `pdftoppm` (render pages to images). Required by `pdf2image` under the hood. |

### Recommended

| Tool            | Package                                    | Usage                                                                                                   |
| --------------- | ------------------------------------------ | ------------------------------------------------------------------------------------------------------- |
| **qpdf**        | `qpdf` (apt/brew)                          | Command-line PDF manipulation: merge, split, rotate, encrypt/decrypt, linearize, repair corrupt PDFs.   |
| **ImageMagick** | `imagemagick` (apt) / `imagemagick` (brew) | Image cropping via `magick`/`convert`. Used for zoom-refinement of form field coordinates (`forms.md`). |

### Optional / Legacy

| Tool              | Package                                    | Usage                                                                               |
| ----------------- | ------------------------------------------ | ----------------------------------------------------------------------------------- |
| **pdftk**         | `pdftk-java` (apt) / `pdftk` (brew)        | Legacy PDF toolkit for merge, split, rotate. Superseded by qpdf for most use cases. |
| **tesseract-ocr** | `tesseract-ocr` (apt) / `tesseract` (brew) | OCR engine required by `pytesseract` for scanned PDF text extraction.               |

---

## Quick Install — All at Once

### Python

```bash
pip install pypdf pdfplumber pdf2image Pillow reportlab pandas pytesseract pypdfium2 numpy
```

### System (Debian/Ubuntu)

```bash
sudo apt install poppler-utils qpdf imagemagick tesseract-ocr pdftk-java
```

### System (macOS)

```bash
brew install poppler qpdf imagemagick tesseract pdftk
```
