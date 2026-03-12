# sim.lobster — Vivado 시뮬레이션 워크플로우

## 개요

Vivado behavioral simulation을 실행하고, AI가 결과를 검토하여 리포트하는 워크플로우.

3계층 구조:
- **Tcl 스크립트**: Vivado 시뮬레이션 실행 및 상태 수집
- **Lobster**: 절차 관리 및 단계 조합
- **llm-task (OpenClaw)**: 시뮬레이션 결과 검토 및 이슈 리포트

자동 패치 없음. 리뷰 결과는 사용자가 직접 판단하여 조치.

프로젝트가 이미 초기화된 상태(`init.lobster` 완료)에서 실행.

## 실행 흐름

```
Phase 1: 시뮬레이션 실행
  run_simulation (launch_simulation, xsim)

Phase 2: 상태 수집
  get_sim_state → state1 (JSON)
    - sim fileset, top, sources, log, errors/warnings

Phase 3: AI 리뷰 (리포트 전용)
  llm-task(state1) → review
    - 테스트벤치 유무, 에러 분석, assertion 체크
    - 이슈와 권장 사항을 리포트로 반환
```

패치 자동 적용 없음. 리뷰 결과를 사용자에게 반환.

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

### 프로젝트 상태

- `init.lobster` 워크플로우가 완료되어 `.xpr` 파일이 존재해야 함
- 시뮬레이션할 소스 파일이 프로젝트에 추가되어 있어야 함

## 실행 방법

```bash
cd vivado-workflow

~/lobster/bin/lobster.js run --file workflows/sim.lobster --args-json '{
  "project_dir": "/home/appuser/projects/my_proj",
  "sim_top": "top_tb",
  "sim_time": "1us"
}'
```

### 최소 실행 (기본값 사용)

```bash
~/lobster/bin/lobster.js run --file workflows/sim.lobster --args-json '{
  "project_dir": "/home/appuser/projects/my_proj"
}'
```

## 인자 (args)

| 인자 | 필수 | 기본값 | 설명 |
|------|------|--------|------|
| `project_dir` | O | — | Vivado 프로젝트 디렉토리 **절대 경로** (.xpr 파일 포함) |
| `sim_top` | X | `""` (fileset 기본값) | 시뮬레이션 top 모듈 (e.g., `top_tb`) |
| `sim_time` | X | `1us` | 시뮬레이션 실행 시간 (e.g., `100ns`, `1us`, `10us`) |
| `sim_fileset` | X | `sim_1` | 시뮬레이션 fileset 이름 |

## 출력

워크플로우 최종 출력은 AI 리뷰 결과 JSON:

```json
{
  "ok": true,
  "data": {
    "sim_fileset": "sim_1",
    "sim_top": "top_tb",
    "sim_time": "1us",
    "has_testbench": true,
    "sim_sources": [
      {"path": "/home/appuser/rtl/top.v", "file_type": "Verilog"},
      {"path": "/home/appuser/tb/top_tb.v", "file_type": "Verilog"}
    ],
    "sim_log": "... xsim output ...",
    "messages": []
  }
}
```

## AI 리뷰 상세

### 검토 항목

1. **테스트벤치 유무** — sim_top이 테스트벤치인지 확인, 없으면 에러
2. **시뮬레이션 소스** — sim fileset에 필요한 파일이 모두 포함되어 있는지
3. **시뮬레이션 실행 결과** — sim_log에서 ERROR/FATAL 메시지 감지
4. **시뮬레이션 시간** — 너무 짧거나 길지 않은지 확인
5. **로그 분석** — assertion failure, $error/$fatal, pass/fail 메시지 감지
6. **일반적인 실수** — clock 미생성, reset 미초기화, `timescale 누락, Verilog/VHDL 혼용

리뷰 결과에 이슈와 권장 사항이 포함됩니다. 자동 패치는 적용되지 않으며, 사용자가 직접 판단하여 조치합니다.

## 관련 파일

```
vivado-workflow/
├── workflows/
│   └── sim.lobster                # 워크플로우 정의
├── scripts/
│   ├── vivado_run.sh              # Vivado batch 래퍼
│   ├── llm_review.sh              # llm-task API 호출 래퍼
│   └── vivado/
│       ├── run_simulation.tcl     # 시뮬레이션 실행
│       └── get_sim_state.tcl      # 시뮬레이션 상태 JSON 수집
├── schemas/
│   └── sim-review.schema.json     # 리뷰 결과 스키마
├── prompts/
│   └── sim-review.md              # 리뷰 프롬프트
└── docs/
    ├── init-workflow.md           # 프로젝트 초기화 워크플로우 문서
    ├── sim-workflow.md            # 이 문서
    └── impl-split-workflow.md     # 구현/bitstream 분리 워크플로우 문서
```

## 테스트벤치 작성 팁

sim 워크플로우가 제대로 동작하려면 테스트벤치가 필요합니다:

```verilog
`timescale 1ns / 1ps

module top_tb;
    reg clk, rst;

    // DUT 인스턴스
    top dut (
        .clk(clk),
        .rst(rst)
    );

    // Clock 생성
    initial clk = 0;
    always #5 clk = ~clk;  // 100MHz

    // 테스트 시퀀스
    initial begin
        rst = 1;
        #100;
        rst = 0;
        #1000;
        $display("TEST PASSED");
        $finish;
    end
endmodule
```

- `sim_top`에 테스트벤치 모듈 이름을 지정하거나, sim fileset의 TOP이 자동 감지됨
- `$display("TEST PASSED")` / `$display("TEST FAILED")` 패턴을 사용하면 AI 리뷰가 결과를 인식
