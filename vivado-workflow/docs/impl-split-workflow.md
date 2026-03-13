# impl_split.lobster — Vivado 구현/비트스트림 분리 워크플로우

## 개요

Vivado **non-project batch flow**로 합성/구현을 수행하고, `post_route.dcp`를 저장한 뒤 **별도 Vivado 실행에서** 비트스트림을 생성하는 워크플로우.

이 워크플로우는 다음 상황을 위해 만들었습니다:
- `route_design` 이후 바로 `write_bitstream`까지 한 프로세스에서 이어서 돌릴 때 불안정한 환경
- checkpoint를 남겨서 구현 단계와 bitgen 단계를 분리하고 싶은 경우
- 마지막에 LLM review로 timing/utilization/bitstream 상태를 요약받고 싶은 경우

3계층 구조:
- **Tcl 스크립트**: 합성/구현, checkpoint reopen, 상태 수집
- **Lobster**: 단계 실행 관리
- **llm-task (OpenClaw)**: 최종 구현 결과 리뷰

## 실행 흐름

```
Phase 1: 구현 단계
  synth_design
  → opt_design
  → place_design
  → route_design
  → write_checkpoint(post_route.dcp)
  → report_timing_summary
  → report_utilization

Phase 2: 비트스트림 단계
  open_checkpoint(post_route.dcp)
  → write_bitstream

Phase 3: 상태 수집 + AI 리뷰
  get_impl_state
  → llm-task(review)
```

핵심 포인트:
- **synth 포함**
- **impl 포함**
- **bitstream 포함**
- 단, **impl(route까지)** 와 **bitgen** 을 분리 실행

## 사전 조건

### 환경 변수 (필수 — 실행 전 반드시 설정)

> **경고**: `OPENCLAW_URL`과 `OPENCLAW_TOKEN`은 `llm_review.sh`를 사용하는 모든 워크플로우 실행 전에 반드시 export 되어야 합니다. 이 변수 없이는 워크플로우가 실패합니다. 우회하거나 생략하지 마세요 — 대체 경로는 없습니다. 매번 명시적으로 설정하세요.

```bash
export OPENCLAW_URL=http://127.0.0.1:18789    # (필수)
export OPENCLAW_TOKEN=<your-token>              # (필수)
```

### 필수 도구

- `~/lobster/bin/lobster.js`
- `vivado`
- `jq`
- `curl`

## 실행 방법

```bash
cd vivado-workflow

~/lobster/bin/lobster.js run --file workflows/impl_split.lobster --args-json '{
  "part": "xc7a35tcpg236-1",
  "project_dir": "/home/appuser/projects/fir_impl",
  "top_module": "fir_filter_basys3_top",
  "sources_json": "[{\"path\":\"/home/appuser/rtl/fir_filter.sv\",\"type\":\"systemverilog\",\"library\":\"work\"},{\"path\":\"/home/appuser/rtl/fir_filter_basys3_top.sv\",\"type\":\"systemverilog\",\"library\":\"work\"}]",
  "constraints_json": "[{\"path\":\"/home/appuser/constraints/fir_filter_basys3.xdc\"}]"
}'
```

## 인자 (args)

| 인자 | 필수 | 설명 |
|------|------|------|
| `part` | O | FPGA 파트 넘버 |
| `project_dir` | O | 산출물 저장 디렉토리 **절대 경로** |
| `top_module` | O | Top 모듈 이름 |
| `sources_json` | O | RTL/top source JSON 배열 |
| `constraints_json` | O | XDC constraint JSON 배열 |

### sources_json 형식

```json
[
  {
    "path": "/home/appuser/rtl/top.sv",
    "type": "systemverilog",
    "library": "work"
  }
]
```

`type`: `verilog` | `systemverilog` | `vhdl`

### constraints_json 형식

```json
[
  {"path": "/home/appuser/constraints/top.xdc"}
]
```

## 출력 산출물

워크플로우 실행 디렉토리 아래에 다음이 생성됩니다:

```text
<project_dir>/impl_split/
├── checkpoints/
│   └── post_route.dcp
├── reports/
│   ├── timing_post_route.rpt
│   └── util_post_route.rpt
└── bitstream/
    └── <top_module>.bit
```

최종 Lobster 출력은 **AI review JSON**입니다.

예시:

```json
{
  "status": "warning",
  "issues": [
    {
      "severity": "info",
      "category": "timing",
      "message": "Post-route timing meets constraints with positive slack."
    },
    {
      "severity": "warning",
      "category": "config",
      "message": "I/O delay constraints are incomplete."
    }
  ],
  "patches": [],
  "summary": "Implementation and bitstream generation succeeded, but the build is not fully constraint-clean."
}
```

## AI 리뷰 상세

최종 review는 다음을 검사합니다:
- post-route checkpoint 존재 여부
- timing/utilization report 존재 여부
- bitstream 존재 여부
- timing met 여부
- utilization 상의 명백한 이상 여부
- bitstream 생성 가능 상태 여부

## 관련 파일

```text
vivado-workflow/
├── workflows/
│   └── impl_split.lobster
├── scripts/
│   ├── vivado_run.sh
│   ├── llm_review.sh
│   └── vivado/
│       ├── run_impl_route_split.tcl
│       ├── write_bitstream_from_checkpoint.tcl
│       └── get_impl_state.tcl
├── prompts/
│   └── impl-review.md
├── schemas/
│   └── impl-review.schema.json
└── docs/
    └── impl-split-workflow.md
```

## 컨테이너 환경 참고

`vivado_run.sh`가 자동으로 처리하는 사항:
- `LD_PRELOAD=/lib/x86_64-linux-gnu/libudev.so.1`
- UTF-8 locale 설정
- run 디렉토리 분리
- Vivado stdout에서 최종 JSON 추출

즉, 이 워크플로우는 **Vivado batch를 안정적으로 돌리기 위한 래퍼 포함** 경로입니다.
