# review.lobster — Hardware Specification Review Workflow

## Overview

A workflow that takes a hardware specification document as input, performs a structured LLM-based review, and returns the review result as JSON.

3-layer architecture:
- **Lobster**: Procedure orchestration (env check → LLM call)
- **llm-task (OpenClaw)**: Spec document review and structured feedback generation
- **JSON Schema**: Output format enforcement

The LLM does not modify the spec directly — it returns issues, missing requirements, and fix proposals as structured JSON.

## Execution Flow

```
Phase 1: Environment Check
  check_env → Verify OPENCLAW_URL, OPENCLAW_TOKEN

Phase 2: AI Review
  llm-task(spec_document) → review (JSON)
    - executive_summary: 3–7 key bullet points
    - solid_points: Well-defined aspects
    - issues: Found problems (severity/topic/problem/fix)
    - missing_requirements: Absent requirements
    - spec_fixes: Proposed text corrections for problematic parts
    - verdict: Final judgment (acceptable / minor / major / not_implementable)
```

## Prerequisites

### Environment Variables (set in shell before running)

```bash
export OPENCLAW_URL=http://127.0.0.1:18789    # OpenClaw gateway URL
export OPENCLAW_TOKEN=<your-token>              # Bearer token
```

### Required Tools

- `~/lobster/bin/lobster.js` — Lobster CLI
- `jq` — JSON processing
- `curl` — HTTP requests

## Usage

```bash
cd spec-workflow

~/lobster/bin/lobster.js run --file workflows/review.lobster --args-json '{
  "spec_document": "<full spec document text (JSON or YAML)>"
}'
```

Reading from a file:

```bash
SPEC=$(cat ../spec-stage/examples/uart_transceiver.spec.yaml)

~/lobster/bin/lobster.js run --file workflows/review.lobster --args-json "$(jq -n --arg spec "$SPEC" '{"spec_document": $spec}')"
```

## Arguments (args)

| Argument | Required | Description |
|----------|----------|-------------|
| `spec_document` | Yes | Full hardware specification text to review (JSON, YAML, or markdown) |

## Output

The workflow outputs structured JSON conforming to `spec-review.schema.json`:

```json
{
  "executive_summary": [
    "Spec defines basic functionality but lacks timing and error handling details",
    "Reset behavior does not specify synchronous vs asynchronous",
    "Interface handshake protocol is incomplete"
  ],
  "solid_points": [
    "Module hierarchy is clearly defined",
    "Pin assignments match the target board"
  ],
  "issues": [
    {
      "id": "ISS-001",
      "severity": "critical",
      "topic": "reset",
      "problem": "Reset is specified as 'active low' but sync/async type is not defined",
      "why_it_matters": "Async reset has metastability risk and different timing analysis than sync reset. Implementation behavior will vary by designer interpretation",
      "recommended_fix": "Specify reset type: 'Asynchronous active-low reset, synchronized internally with a 2-FF synchronizer'"
    }
  ],
  "missing_requirements": [
    {
      "topic": "error_handling",
      "description": "Behavior on frame reception error is undefined. Must specify abort/retry/ignore policy"
    }
  ],
  "spec_fixes": [
    {
      "section": "interface.reset",
      "original_text": "Active low reset",
      "revised_text": "Asynchronous active-low reset (active when rst_n = 0). Internally synchronized using a 2-stage flip-flop synchronizer before use in the clk domain. Minimum reset assertion duration: 2 clock cycles."
    }
  ],
  "verdict": {
    "status": "needs_major_revision",
    "summary": "Critical timing and error handling requirements are missing; the spec cannot be safely implemented as-is"
  }
}
```

## Review Checklist

Items the LLM reviews:

- Signal direction / ownership ambiguity
- Clocking edge semantics
- Reset behavior (sync/async, active level, duration)
- Handshake timing (setup/hold, min pulse width)
- Frame start/end conditions
- Abort / error cases
- Idle behavior
- Tri-state / OE responsibility
- Bit width / endianness / bit order
- Latency expectations (min/max/typical)
- Backpressure / ready-valid assumptions
- CDC or timing-domain assumptions
- Synthesizability (inferred latches, combinational loops)
- Verification blind spots

## Severity Levels

| Severity | Meaning |
|----------|---------|
| `critical` | May lead to implementation failure or silicon bugs |
| `major` | Different interpretations could produce different behavior |
| `minor` | Clarity/readability improvement needed but no major implementation impact |

## Verdict Levels

| Status | Meaning |
|--------|---------|
| `acceptable_as_is` | Spec is implementable as written |
| `needs_minor_revision` | Implementable after small corrections |
| `needs_major_revision` | Core requirements need to be addressed |
| `not_implementable_safely` | Cannot be safely implemented from this spec |

## Related Files

```
spec-workflow/
├── workflows/
│   └── review.lobster              # Workflow definition
├── scripts/
│   └── llm_review.sh               # llm-task API caller
├── schemas/
│   └── spec-review.schema.json     # Review result schema
├── prompts/
│   └── spec-review.md              # Review prompt
└── docs/
    └── review-workflow.md          # This document
```
