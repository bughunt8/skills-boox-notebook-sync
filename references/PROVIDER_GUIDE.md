# Vision LLM Provider Guide

## Provider Comparison

| Feature | GPT-4o (OpenAI) | Claude 3.5 Sonnet | Gemini 1.5 Flash |
|---|---|---|---|
| Accuracy (English) | ★★★★★ | ★★★★★ | ★★★★☆ |
| Accuracy (CJK: zh/ja/ko) | ★★★★☆ | ★★★★★ | ★★★★☆ |
| Multi-page PDF support | Via page splitting | Native PDF blocks | Via page splitting |
| Speed | Fast | Medium | Fastest |
| Cost (per note ~5 pages) | ~$0.10–0.20 | ~$0.08–0.15 | ~$0.01–0.03 |
| Privacy | Data used for training (opt-out available) | Not used for training | Not used for training |
| Rate limits | Generous | Moderate | Very generous |

## Setting Up Each Provider

### OpenAI GPT-4o

```bash
export BOOX_OCR_PROVIDER=openai
export OPENAI_API_KEY=sk-...
```

Get your key: https://platform.openai.com/api-keys
Cost: $2.50 / 1M input tokens (images billed by tile, ~170–340 tokens per 512px tile)

### Anthropic Claude 3.5 Sonnet

```bash
export BOOX_OCR_PROVIDER=anthropic
export ANTHROPIC_API_KEY=sk-ant-...
```

Get your key: https://console.anthropic.com/settings/keys
Best for: complex handwriting, non-Latin scripts, preserving structure

### Google Gemini 1.5 Flash

```bash
export BOOX_OCR_PROVIDER=google
export GOOGLE_API_KEY=AIza...
```

Get your key: https://aistudio.google.com/app/apikey
Best for: cost-sensitive bulk processing, fastest turnaround

## Language Hints

Set `BOOX_READER_LANG_HINT` to help the model focus:

| Language | Code | Notes |
|---|---|---|
| English | en | Default |
| Traditional Chinese | zh-TW | For HK/Taiwan users |
| Simplified Chinese | zh-CN | Mainland Chinese |
| Japanese | ja | |
| Cantonese (romanized) | yue | Use zh-TW for character-based |
| Mixed EN/ZH | en,zh | Comma-separate multiple |
