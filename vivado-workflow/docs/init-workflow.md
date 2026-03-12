# init.lobster — Vivado 프로젝트 초기화 워크플로우

## 개요

Vivado FPGA 프로젝트를 생성하고, AI가 프로젝트 상태를 검토하여 자동으로 패치를 적용하는 워크플로우.

3계층 구조:
- **Tcl 스크립트**: Vivado 명령 실행 (한 스크립트 = 한 책임)
- **Lobster**: 절차 관리 및 단계 조합
- **llm-task (OpenClaw)**: 프로젝트 상태 검토 및 패치 제안

LLM이 Vivado를 직접 조작하지 않고, 정해진 Tcl 액션을 Lobster가 조합하고, llm-task가 사이사이 검토하는 구조.

## 실행 흐름

```
Phase 1: 프로젝트 생성 및 구성
  create_project → add_sources → add_constraints → set_top → update_compile_order

Phase 2: 상태 수집
  get_project_state → state1 (JSON)

Phase 3: 1차 AI 리뷰
  llm-task(state1) → review1
    - patches가 있으면 Phase 4로
    - patches가 없으면 (pass) Phase 5로

Phase 4: 자동 패치 적용
  apply_patch(review1.patches)

Phase 5: 상태 재수집 + 2차 AI 리뷰
  get_project_state → state2
  llm-task(state2) → review2 (더 엄격, 패치 제안 없음)

Phase 6: 최종 상태 출력
  get_project_state → final_state (워크플로우 결과)
```

최대 2회 리뷰 사이클. 패치는 승인 없이 자동 적용.

## 사전 조건

### 환경 변수 (셸에 미리 설정)

```bash
export OPENCLAW_URL=http://127.0.0.1:18789    # OpenClaw gateway URL
export OPENCLAW_TOKEN=<your-token>              # Bearer token
```

### 필수 도구

- `~/lobster/bin/lobster.js` — Lobster CLI
- `vivado` — Vivado (PATH에 등록, 컨테이너 내)
- `jq` — JSON 처리
- `curl` — HTTP 요청

## 실행 방법

```bash
cd vivado-workflow

~/lobster/bin/lobster.js run --file workflows/init.lobster --args-json '{
  "project_name": "my_proj",
  "part": "xc7a35tcpg236-1",
  "project_dir": "/home/appuser/projects/my_proj",
  "top_module": "top",
  "sources_json": "[{\"path\":\"/home/appuser/rtl/top.v\",\"type\":\"verilog\",\"library\":\"work\"}]",
  "constraints_json": "[{\"path\":\"/home/appuser/constraints/pins.xdc\"}]"
}'
```

## 인자 (args)

| 인자 | 필수 | 설명 |
|------|------|------|
| `project_name` | O | Vivado 프로젝트 이름 |
| `part` | O | FPGA 파트 넘버 (e.g., `xc7a35tcpg236-1`) |
| `project_dir` | O | 프로젝트 디렉토리 **절대 경로** |
| `top_module` | O | Top 모듈 이름 |
| `sources_json` | O | 소스 파일 JSON 배열. 모든 경로 **절대 경로** |
| `constraints_json` | X | 제약 파일 JSON 배열. 기본값 `[]` |

### sources_json 형식

```json
[
  {
    "path": "/home/appuser/rtl/top.v",
    "type": "verilog",
    "library": "work"
  },
  {
    "path": "/home/appuser/rtl/uart.sv",
    "type": "systemverilog",
    "library": "work"
  }
]
```

`type`: `verilog` | `systemverilog` | `vhdl`

### constraints_json 형식

```json
[
  {"path": "/home/appuser/constraints/pins.xdc"}
]
```

## 경로 규칙

- **절대 경로**: `project_dir`, `sources_json[].path`, `constraints_json[].path`
  - 모든 Vivado 관련 경로는 `/home/appuser/...` 형태의 절대 경로
- **상대 경로**: 워크플로우 내부 스크립트 참조 (`scripts/vivado_run.sh`, `prompts/...`, `schemas/...`)
  - `vivado-workflow/` 디렉토리 기준 상대 경로

## 출력

워크플로우 최종 출력은 `get_project_state`의 JSON:

```json
{
  "ok": true,
  "data": {
    "project": {
      "name": "my_proj",
      "part": "xc7a35tcpg236-1",
      "directory": "/home/appuser/projects/my_proj",
      "board_part": ""
    },
    "sources": [
      {"path": "/home/appuser/rtl/top.v", "type": "verilog", "library": "work", "fileset": "sources_1"}
    ],
    "constraints": [
      {"path": "/home/appuser/constraints/pins.xdc", "used_in": ["synthesis", "implementation"]}
    ],
    "top_module": "top",
    "compile_order": {
      "status": "resolved",
      "files": ["/home/appuser/rtl/top.v"]
    },
    "messages": []
  }
}
```

## AI 리뷰 상세

### 1차 리뷰 (review1)

검토 항목:
- 소스 파일 누락/중복
- 제약 파일 누락
- Top 모듈 불일치
- 컴파일 순서 미해결
- 파트 호환성
- Inferred memory 감지 시 BRAM IP 전환 권장

패치 가능 액션: `add_source`, `remove_source`, `add_constraint`, `remove_constraint`, `set_top`, `set_property`

### 2차 리뷰 (review2)

- 1차 리뷰 패치가 올바르게 적용되었는지 확인
- 패치로 인한 regression 체크
- 패치 제안 없음 (리포트만)
- 더 엄격한 기준

## 관련 파일

```
vivado-workflow/
├── workflows/
│   └── init.lobster              # 워크플로우 정의
├── scripts/
│   ├── vivado_run.sh             # Vivado batch 래퍼
│   ├── llm_review.sh             # llm-task API 호출 래퍼
│   └── vivado/
│       ├── create_project.tcl    # 프로젝트 생성
│       ├── add_sources.tcl       # RTL 소스 추가
│       ├── add_constraints.tcl   # XDC 제약 추가
│       ├── set_top.tcl           # Top 모듈 설정
│       ├── update_compile_order.tcl  # 컴파일 순서 갱신
│       ├── get_project_state.tcl # 프로젝트 상태 JSON 수집
│       └── apply_patch.tcl       # 패치 액션 적용
├── schemas/
│   ├── project-state.schema.json # 프로젝트 상태 스키마
│   ├── init-review.schema.json   # 리뷰 결과 스키마
│   └── patch-action.schema.json  # 패치 액션 스키마
├── prompts/
│   ├── init-review.md            # 1차 리뷰 프롬프트
│   └── init-review-cycle2.md     # 2차 리뷰 프롬프트
└── docs/
    ├── init-workflow.md          # 이 문서
    ├── sim-workflow.md           # 시뮬레이션 워크플로우 문서
    └── impl-split-workflow.md    # 구현/bitstream 분리 워크플로우 문서
```

## 컨테이너 환경 참고

`vivado_run.sh`가 자동으로 처리하는 컨테이너 워크어라운드:

- `LD_PRELOAD=/lib/x86_64-linux-gnu/libudev.so.1` — libudev/WebTalk 크래시 방지
- `LANG=en_US.UTF-8` — UTF-8 locale 설정
- Run 디렉토리 격리 — `$VIVADO_PROJECT_DIR/run/`에서 Vivado 실행, workspace 오염 방지
- Failed child run reset — `apply_patch.tcl`에서 retry 시 failed 상태 run을 자동 reset
