# pptxgenjs Pitfalls Discovered in Practice

These are bugs caught during real deck generation that aren't in the official docs.
See the main `pptxgenjs.md` reference for the full API tutorial.

---

## Visual Rendering Traps

### Overlay shapes always render IN FRONT of text
**Symptom:** A semi-transparent `RECTANGLE` placed "for effect" behind a headline (e.g., a
`transparency: 70` color wash to highlight "10x Faster") completely obscures the text it
was meant to accent. In PowerPoint's rendering order, shapes added *after* a text box sit
on top of it regardless of intended z-order.

**Fix:** Never use overlay shapes for text highlights. Use rich-text arrays instead:
```javascript
slide.addText([
  { text: "Tailored Resumes.\n", options: { color: "FFFFFF" } },
  { text: "10x Faster.\n",       options: { color: "F59E0B", bold: true } },  // gold accent
  { text: "Powered by AI.",      options: { color: "FFFFFF" } },
], { x: 0.5, y: 1.2, w: 6.5, h: 2.1, fontFace: "Arial Black", fontSize: 38, margin: 0 });
```

---

### Logo triple-layer causes wordmark overlap
**Symptom:** Building a logo as (1) background `addText("BrandName")` + (2) `addShape` icon
square + (3) `addText("R")` letter + (4) `addText("BrandName")` wordmark results in two
copies of "BrandName" stacked on top of each other, making the logo illegible.

**Root cause:** Layer (1) was intended as a sizing placeholder but persists as a visible
text element.

**Correct 3-call pattern:**
```javascript
// ✅ Icon square
slide.addShape(pres.shapes.RECTANGLE, {
  x: 0.5, y: 0.38, w: 0.38, h: 0.38,
  fill: { color: "2D6EE8" }, line: { color: "2D6EE8", width: 0 }
});
// ✅ Letter inside square
slide.addText("R", {
  x: 0.5, y: 0.38, w: 0.38, h: 0.38,
  fontFace: "Arial Black", fontSize: 15, color: "FFFFFF",
  align: "center", valign: "middle", margin: 0
});
// ✅ Brand name to the right
slide.addText("BrandName", {
  x: 0.95, y: 0.38, w: 2.8, h: 0.38,
  fontFace: "Arial Black", fontSize: 15, color: "FFFFFF",
  valign: "middle", margin: 0
});
// ❌ DELETE any prior addText("BrandName") used as a size scaffold
```

---

## Card Layout Bugs

### Testimonial/quote cards: text clips at bottom
**Symptom:** The last 1–2 words of a multi-sentence quote are cut off. The card shape's
height is just long enough for the text at one font size, but quotes vary in length.

**Fix:** Always allocate ≥ 1.75" for quote card height. Split quote and attribution into
separate `addText` calls so you can independently size them:
```javascript
// Card shape
slide.addShape(pres.shapes.RECTANGLE, {
  x, y: 3.72, w: 3.05, h: 1.75,   // ← 1.75 minimum
  fill: { color: "FFFFFF" }, ...
});
// Quote body — generous height
slide.addText(quote, {
  x: x + 0.14, y: 4.18, w: 2.78, h: 0.95,  // ← separate from attribution
  fontFace: "Calibri", fontSize: 9, color: "64748B", italic: true, margin: 0
});
// Attribution — on its own line below
slide.addText(attribution, {
  x: x + 0.14, y: 5.16, w: 2.78, h: 0.22,
  fontFace: "Calibri", fontSize: 8.5, color: "2D6EE8", bold: true, margin: 0
});
```

---

## QA Tooling

### Python rasterizer (fallback when LibreOffice is absent) is not pixel-perfect
When `soffice` is unavailable and you fall back to a `python-pptx + Pillow` rasterizer
for visual QA, expect **false positives** for:
- Broken emoji / icon glyphs (they appear as `[]` boxes)
- Stray/orphan shapes (python-pptx may mis-place some z-ordered elements)
- Text overflow (text wrapping behaviour differs from PowerPoint)

**Use the rasterizer for layout structure and rough content checks only.**
Always cross-validate with `markitdown output.pptx` to confirm text content is present.
Defer definitive visual sign-off to a real LibreOffice or PowerPoint render.

---

## npm Install When Global Write Is Blocked

If `npm install -g pptxgenjs` fails with permission denied (no root access), use a
local prefix:
```bash
npm install --prefix /opt/data/npm-global pptxgenjs react react-dom react-icons sharp
# Then run scripts with:
NODE_PATH=/opt/data/npm-global/lib/node_modules node your-script.js
```
