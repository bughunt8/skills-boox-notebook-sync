# BOOX Device Setup Guide

## Step 1 — Enable Auto PDF Export

This is the most critical step. The skill reads exported PDFs/PNGs, not the
proprietary `.note` format.

1. Open the **Notes** app on your BOOX device.
2. Tap **☰** (menu) → **Settings** → **Sync Settings**.
3. Under **Export Format**, select **Vector PDF** (preferred — vector text scales
   without blur) or **PNG** (rasterized, may need contrast enhancement in OCR).
4. Enable **Auto Export** — the device will export a PDF every time you close a note.
5. Optionally set **Export Destination** to a cloud folder (Step 2).

## Step 2 — Choose a Sync Method

### Option A: Google Drive (Recommended)

Best for users already in Google Workspace.

1. Install the **Google Drive** app from the Play Store on your BOOX.
2. Sign in with your Google account.
3. In Notes → Sync Settings → **Export to Third-Party Accounts** → **Google Drive**.
4. Choose a folder (e.g., `BOOX/Notes`).
5. On your desktop/server: install Google Drive for Desktop.
6. Set `BOOX_SYNC_PATH` to the local mirror path:
   - macOS: `~/Library/CloudStorage/GoogleDrive-you@gmail.com/My Drive/BOOX/Notes`
   - Linux: `~/GoogleDrive/BOOX/Notes` (via `google-drive-ocamlfuse` or `rclone`)
   - Windows: `C:\Users\You\Google Drive\BOOX\Notes`

### Option B: Syncthing (Privacy-First, No Cloud)

Best for users who want zero cloud dependency (LAN/direct sync).

1. Install **Syncthing** on both your BOOX device (Play Store) and your computer.
2. On BOOX: add a shared folder pointing to `/storage/emulated/0/NOTE/` (where BOOX
   auto-exports PDFs when Auto Export is on).
3. On your computer: add the same folder as the sync target.
4. Set `BOOX_SYNC_PATH` to the local Syncthing target folder.
5. Syncthing syncs over Wi-Fi automatically — no internet required.

**BOOX auto-export path** (for Syncthing):
```
/storage/emulated/0/NOTE/           ← native .note files
/storage/emulated/0/NOTE/exported/  ← auto-exported PDFs (set as Syncthing source)
```

### Option C: Dropbox

Same process as Google Drive but using the Dropbox app.
Set `BOOX_SYNC_PATH` to your local Dropbox folder containing the BOOX exports.

### Option D: Boox Cloud + Send2BOOX

Use the built-in BOOX cloud sync, then manually download PDFs via the
[Send2BOOX web portal](https://send2boox.com). Less automation-friendly; manual step needed.

## Step 3 — Confirm Export is Working

1. Write a test note on your BOOX and close it.
2. Wait 30–60 seconds for sync.
3. Run: `python scripts/boox_ocr.py --list`
4. You should see the exported PDF listed.

## Recommended BOOX Settings for Best OCR Accuracy

| Setting | Recommended Value | Why |
|---|---|---|
| Pen pressure sensitivity | Medium–High | Creates darker, more contrast strokes |
| Background | White | Maximum contrast for OCR |
| Stroke color | Black | Best contrast |
| Export format | Vector PDF | Scalable, no compression artifacts |
| Page size | A4 or Letter | Standard sizing matches model training |
| Writing style | Printed (not cursive) | Higher accuracy across all providers |
