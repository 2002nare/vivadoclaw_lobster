# review_and_refine.lobster — Hardware Spec Review + Critical-Fix Refinement

## Overview

Reviews a hardware specification, then automatically fixes critical issues and produces timestamped output files with a human-readable changelog.

Flow:
1. Receive spec document, save with timestamp
2. AI review (same as `review.lobster`) — structured JSON
3. If critical issues found: AI refine — apply fixes to spec text
4. Save refined spec + changelog (all timestamped)

3-layer architecture:
- **Lobster**: Procedure orchestration (env check → pipeline script)
- **llm-task (OpenClaw)**: Review + refine via separate LLM calls
- **JSON Schema**: Output format enforcement for both review and refine

## Prerequisites

### Environment Variables (REQUIRED)

```bash
export OPENCLAW_URL=http://127.0.0.1:18789    # OpenClaw gateway URL (REQUIRED)
export OPENCLAW_TOKEN=<your-token>              # Bearer token (REQUIRED)
```

### Required Tools

- `~/lobster/bin/lobster.js` — Lobster CLI
- `jq` — JSON processing
- `curl` — HTTP requests

## Usage

```bash
cd spec-tool

SPEC=$(cat ../spec-stage/examples/uart_transceiver.spec.yaml)

~/lobster/bin/lobster.js run --file tools/review_and_refine.lobster \
  --args-json "$(jq -n --arg spec "$SPEC" '{"spec_document": $spec}')"
```

## Arguments (args)

| Argument | Required | Description |
|----------|----------|-------------|
| `spec_document` | Yes | Full hardware specification text to review and refine (JSON, YAML, or markdown) |

## Output Files

All outputs are saved to `output/` with a shared timestamp:

```
output/
  spec_input_<timestamp>.txt      — original spec input
  review_<timestamp>.json         — full review result (same schema as review.lobster)
  refine_<timestamp>.json         — refine result (changes + refined spec)
  spec_refined_<timestamp>.txt    — refined spec document only
  changelog_<timestamp>.log       — human-readable change log
```

### Refine Result Schema

```json
{
  "refined_spec": "...(full corrected spec text)...",
  "changes": [
    {
      "issue_id": "ISS-001",
      "status": "applied",
      "section": "interface.reset",
      "original_text": "Active low reset",
      "revised_text": "Asynchronous active-low reset...",
      "rationale": "Reset type must be specified to avoid metastability"
    }
  ],
  "summary": {
    "total_critical_issues": 2,
    "applied": 1,
    "deferred": 1,
    "description": "Applied 1 critical fix, deferred 1 that requires human judgment"
  }
}
```

### Changelog Format

The `changelog_<timestamp>.log` includes:
- Review verdict and issue counts
- Critical issues listed with ID, topic, problem, recommended fix
- Applied changes with before/after text and rationale
- Deferred changes with reason

## Behavior

- Only **critical** issues are auto-fixed. Major and minor issues are reported but not modified.
- If no critical issues are found, the refine step is skipped entirely.
- Changes can have status `applied` or `deferred` (when the fix requires human judgment).

## Related Files

```
spec-tool/
├── tools/
│   └── review_and_refine.lobster       # Workflow definition
├── scripts/
│   ├── review_and_refine_run.sh        # Pipeline orchestrator
│   ├── llm_review.sh                   # Review API caller
│   └── llm_refine.sh                   # Refine API caller
├── schemas/
│   ├── spec-review.schema.json         # Review result schema
│   └── spec-refine.schema.json         # Refine result schema
├── prompts/
│   ├── spec-review.md                  # Review prompt
│   └── spec-refine.md                  # Refine prompt
└── docs/
    ├── review-tool.md                  # Review-only tool docs
    └── review-and-refine-tool.md       # This document
```
