# spec-tool

Lobster tools for AI-powered hardware specification review and auto-refinement.

## Tools

| Tool | Description |
|------|-------------|
| [`review.lobster`](tools/review.lobster) | Review a hardware spec and return structured JSON feedback (issues, missing requirements, verdict) |
| [`review_and_refine.lobster`](tools/review_and_refine.lobster) | Review + auto-fix critical issues, with timestamped output files and changelog |

## Quick start

```bash
export OPENCLAW_URL=http://127.0.0.1:18789
export OPENCLAW_TOKEN=<your-token>

cd spec-tool

SPEC=$(cat ../spec-stage/examples/uart_transceiver.spec.yaml)

~/lobster/bin/lobster.js run --file tools/review.lobster \
  --args-json "$(jq -n --arg spec "$SPEC" '{"spec_document": $spec}')"
```

## Structure

```
spec-tool/
  tools/          Lobster tool definitions
  scripts/        Shell wrappers (llm_review.sh, llm_refine.sh, review_and_refine_run.sh)
  schemas/        JSON schemas for review/refine output
  prompts/        LLM review/refine prompts
  docs/           Per-tool documentation
```

## Documentation

- [review-tool.md](docs/review-tool.md) — Spec review tool
- [review-and-refine-tool.md](docs/review-and-refine-tool.md) — Spec review + auto-refine tool
