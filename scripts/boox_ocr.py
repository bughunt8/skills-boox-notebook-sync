#!/usr/bin/env python3
"""
boox_ocr.py — Vision LLM OCR for BOOX handwritten notes
Supports: OpenAI GPT-4o, Anthropic Claude 3.5 Sonnet, Google Gemini 1.5 Flash
"""

import argparse
import base64
import json
import os
import sys
import time
from pathlib import Path

# ── optional imports resolved at runtime ──────────────────────────────────────
try:
    import fitz  # PyMuPDF
    HAS_FITZ = True
except ImportError:
    HAS_FITZ = False

try:
    from PIL import Image, ImageEnhance
    import io
    HAS_PIL = True
except ImportError:
    HAS_PIL = False

# ── config ────────────────────────────────────────────────────────────────────
SYNC_PATH = Path(os.environ.get("BOOX_SYNC_PATH", "~/Documents/BOOX")).expanduser()
DEFAULT_PROVIDER = os.environ.get("BOOX_OCR_PROVIDER", "openai")
LOG_PATH = Path("~/.hermes/logs/boox-reader.log").expanduser()

SYSTEM_PROMPT = """You are an expert handwriting transcription assistant.
Your task is to faithfully transcribe all handwritten content from the image.

Rules:
- Preserve the original structure: headings, bullet lists, numbered lists, tables.
- Output clean Markdown. Use # for headings, - for bullets, | for tables.
- If text is ambiguous, output your best guess followed by [?].
- Do NOT add commentary or explanations — only the transcribed content.
- Preserve the language of the handwriting exactly (do not translate).
- If diagrams or drawings are present, describe them briefly in italics: *[Diagram: ...]*
"""

# ── helpers ───────────────────────────────────────────────────────────────────

def encode_image(img_path: Path, enhance: bool = False) -> str:
    """Return base64-encoded image, optionally with contrast enhancement."""
    if enhance and HAS_PIL:
        img = Image.open(img_path).convert("L")  # grayscale
        img = ImageEnhance.Contrast(img).enhance(2.0)
        buf = io.BytesIO()
        img.save(buf, format="PNG")
        return base64.b64encode(buf.getvalue()).decode()
    return base64.b64encode(img_path.read_bytes()).decode()


def pdf_to_images(pdf_path: Path, dpi: int = 150) -> list[bytes]:
    """Convert PDF pages to PNG bytes using PyMuPDF."""
    if not HAS_FITZ:
        raise RuntimeError("PyMuPDF not installed. Run: pip install pymupdf")
    doc = fitz.open(str(pdf_path))
    pages = []
    for page in doc:
        mat = fitz.Matrix(dpi / 72, dpi / 72)
        pix = page.get_pixmap(matrix=mat, colorspace=fitz.csGRAY)
        pages.append(pix.tobytes("png"))
    doc.close()
    return pages


def ocr_openai(image_b64: str, lang: str, model: str = "gpt-4o") -> str:
    import openai
    client = openai.OpenAI(api_key=os.environ["OPENAI_API_KEY"])
    resp = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": [
                {"type": "text", "text": f"Transcribe this handwritten note. Language: {lang}"},
                {"type": "image_url", "image_url": {
                    "url": f"data:image/png;base64,{image_b64}",
                    "detail": "high"
                }}
            ]}
        ],
        max_tokens=4096,
    )
    return resp.choices[0].message.content.strip()


def ocr_anthropic(image_b64: str, lang: str, model: str = "claude-3-5-sonnet-20241022") -> str:
    import anthropic
    client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
    resp = client.messages.create(
        model=model,
        max_tokens=4096,
        system=SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": [
                {"type": "image", "source": {
                    "type": "base64",
                    "media_type": "image/png",
                    "data": image_b64
                }},
                {"type": "text", "text": f"Transcribe this handwritten note. Language: {lang}"}
            ]
        }]
    )
    return resp.content[0].text.strip()


def ocr_google(image_b64: str, lang: str, model: str = "gemini-1.5-flash") -> str:
    import google.generativeai as genai
    genai.configure(api_key=os.environ["GOOGLE_API_KEY"])
    m = genai.GenerativeModel(model)
    img_data = {"mime_type": "image/png", "data": image_b64}
    resp = m.generate_content([
        SYSTEM_PROMPT,
        img_data,
        f"Transcribe this handwritten note. Language: {lang}"
    ])
    return resp.text.strip()


def ocr_page(image_b64: str, provider: str, lang: str) -> str:
    """Dispatch to correct provider."""
    if provider == "openai":
        return ocr_openai(image_b64, lang)
    elif provider == "anthropic":
        return ocr_anthropic(image_b64, lang)
    elif provider == "google":
        return ocr_google(image_b64, lang)
    else:
        raise ValueError(f"Unknown provider: {provider}. Use: openai | anthropic | google")


def process_file(file_path: Path, provider: str, lang: str, fmt: str,
                 enhance: bool, delay: float) -> str:
    """Process a single PDF or image file and return transcribed Markdown."""
    suffix = file_path.suffix.lower()
    results = []

    if suffix == ".pdf":
        pages = pdf_to_images(file_path)
        total = len(pages)
        print(f"  Processing {total} page(s)...", file=sys.stderr)
        for i, page_bytes in enumerate(pages, 1):
            print(f"  Page {i}/{total}", file=sys.stderr)
            b64 = base64.b64encode(page_bytes).decode()
            if enhance and HAS_PIL:
                img = Image.open(io.BytesIO(page_bytes)).convert("L")
                img = ImageEnhance.Contrast(img).enhance(2.0)
                buf = io.BytesIO()
                img.save(buf, format="PNG")
                b64 = base64.b64encode(buf.getvalue()).decode()
            text = ocr_page(b64, provider, lang)
            results.append(f"<!-- Page {i} -->\n{text}")
            if i < total:
                time.sleep(delay)
    elif suffix in (".png", ".jpg", ".jpeg"):
        b64 = encode_image(file_path, enhance=enhance)
        text = ocr_page(b64, provider, lang)
        results.append(text)
    else:
        raise ValueError(f"Unsupported file type: {suffix}. Use PDF or PNG/JPG.")

    full_text = "\n\n---\n\n".join(results)

    if fmt == "json":
        output = json.dumps({
            "source": str(file_path),
            "provider": provider,
            "language": lang,
            "pages": len(results),
            "content": full_text
        }, ensure_ascii=False, indent=2)
    elif fmt == "plain":
        # strip Markdown syntax
        import re
        output = re.sub(r"[#*`_\[\]|>-]{1,3}", "", full_text)
    else:
        output = f"# {file_path.stem}\n\n{full_text}"

    # write sidecar
    sidecar = file_path.with_suffix(".md")
    sidecar.write_text(output, encoding="utf-8")
    print(f"  ✓ Saved: {sidecar}", file=sys.stderr)
    return output


# ── CLI ───────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="BOOX Vision OCR — transcribe handwritten BOOX notes")
    parser.add_argument("--file", help="Path to a PDF or image file to transcribe")
    parser.add_argument("--watch", action="store_true",
                        help="Continuously watch $BOOX_SYNC_PATH for new files")
    parser.add_argument("--watch-once", action="store_true",
                        help="Process all unprocessed files and exit")
    parser.add_argument("--list", action="store_true",
                        help="List available notes in $BOOX_SYNC_PATH")
    parser.add_argument("--verify", metavar="FILENAME",
                        help="Re-display the last transcription for a file")
    parser.add_argument("--provider", default=DEFAULT_PROVIDER,
                        choices=["openai", "anthropic", "google"],
                        help="Vision LLM provider (default: $BOOX_OCR_PROVIDER)")
    parser.add_argument("--lang", default=os.environ.get("BOOX_READER_LANG_HINT", "en"),
                        help="Language hint ISO 639-1 (default: en)")
    parser.add_argument("--format", default="markdown",
                        choices=["markdown", "json", "plain"],
                        dest="fmt", help="Output format")
    parser.add_argument("--enhance", action="store_true",
                        help="Apply contrast enhancement before OCR")
    parser.add_argument("--delay", type=float, default=1.0,
                        help="Seconds between page API calls (default: 1.0)")
    parser.add_argument("--sync-path", default=str(SYNC_PATH),
                        help="Override $BOOX_SYNC_PATH for this run")
    args = parser.parse_args()

    sync_dir = Path(args.sync_path).expanduser()

    # ── list ──
    if args.list:
        files = sorted(sync_dir.rglob("*.pdf")) + sorted(sync_dir.rglob("*.png"))
        if not files:
            print("No PDF or PNG files found in:", sync_dir)
        for f in files:
            tag = " [transcribed]" if f.with_suffix(".md").exists() else ""
            print(f"  {f.relative_to(sync_dir)}{tag}")
        return

    # ── verify ──
    if args.verify:
        target = "last" if args.verify == "last" else args.verify
        if target == "last":
            mds = sorted(sync_dir.rglob("*.md"), key=lambda p: p.stat().st_mtime)
            if not mds:
                print("No transcriptions found.")
                return
            target_path = mds[-1]
        else:
            target_path = sync_dir / Path(target).with_suffix(".md")
        if target_path.exists():
            print(target_path.read_text(encoding="utf-8"))
        else:
            print(f"Transcription not found: {target_path}")
        return

    # ── single file ──
    if args.file:
        fp = Path(args.file).expanduser()
        if not fp.exists():
            print(f"ERROR: File not found: {fp}", file=sys.stderr)
            sys.exit(1)
        print(process_file(fp, args.provider, args.lang, args.fmt, args.enhance, args.delay))
        return

    # ── watch-once ──
    processed_set = set()

    def process_new():
        files = list(sync_dir.rglob("*.pdf")) + list(sync_dir.rglob("*.png"))
        for fp in files:
            if fp in processed_set:
                continue
            sidecar = fp.with_suffix(".md")
            if sidecar.exists():
                processed_set.add(fp)
                continue
            print(f"\n→ Processing: {fp.name}", file=sys.stderr)
            try:
                process_file(fp, args.provider, args.lang, args.fmt, args.enhance, args.delay)
                processed_set.add(fp)
            except Exception as e:
                print(f"  ✗ Error: {e}", file=sys.stderr)

    if args.watch_once:
        process_new()
        return

    # ── continuous watch ──
    if args.watch:
        LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        print(f"Watching: {sync_dir}  (Ctrl+C to stop)", file=sys.stderr)
        while True:
            process_new()
            time.sleep(30)

    # no mode selected
    parser.print_help()


if __name__ == "__main__":
    main()
