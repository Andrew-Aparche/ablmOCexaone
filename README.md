# ablmOCexaone · 에이블램엑사원설치

**OpenCode(오픈소스 코딩 에이전트)에 LG EXAONE 모델을 한 번에 연결해 주는 AI 에이전트용 플러그인**이에요.
Claude Code에서 `에이블램엑사원설치` 한 마디면 아래 4단계를 알아서 진행해요.

| 단계 | 하는 일 |
|---|---|
| 1. 설치 확인 | OpenCode CLI가 있는지 확인하고, 없으면 공식 설치 파일로 설치 |
| 2. 공급자 추가 | `~/.config/opencode/opencode.json`에 EXAONE 공급자 추가 (기존 설정은 백업) |
| 3. 키 저장 | 보안 입력 창으로 API 키를 받아서 **Windows는 사용자 환경변수**, **macOS는 키체인**에 저장 |
| 4. 연결 확인 | 설정 파일과 키가 제대로 들어갔는지, EXAONE 서버 인증이 되는지 확인 |

> 🔒 **API 키는 채팅창에 절대 붙여넣지 않아요.** 키는 화면에 뜨는 보안 입력 창(●로 가려짐)으로만 입력하고, 프로젝트 파일에도 저장되지 않아요.

---

## 준비물

- EXAONE API 키 ([EXAONE 문서](https://docs.exaone.ai/ko/docs/agent-start) 참고)
- [Claude Code](https://claude.com/claude-code)

---

## 방법 A. Claude Code 플러그인으로 설치 (추천)

Claude Code를 열고 아래 두 줄을 차례로 입력하세요.

```text
/plugin marketplace add Andrew-Aparche/ablmOCexaone
/plugin install ablm-oc-exaone@ablm
```

설치가 끝나면 Claude Code를 다시 시작하고 이렇게 입력하세요.

```text
에이블램엑사원설치
```

또는 슬래시 명령어로 불러도 돼요: `/에이블램엑사원설치`

> Claude Code에서 슬래시 명령어는 `/ablm-oc-exaone:에이블램엑사원설치`처럼 플러그인 이름이 앞에 붙어서 보일 수 있어요. `/에이블`까지만 쳐도 자동완성으로 나와요.

## 방법 B. Codex 같은 다른 에이전트에서 쓰기

`skills/ablm-exaone-install` 폴더가 표준 스킬(SKILL.md) 형식이라 그대로 복사해서 쓸 수 있어요.

```bash
git clone https://github.com/Andrew-Aparche/ablmOCexaone.git
# Codex
mkdir -p ~/.codex/skills && cp -r ablmOCexaone/skills/ablm-exaone-install ~/.codex/skills/
```

그다음 에이전트에게 "에이블램엑사원설치"라고 말하면 돼요.
(ChatGPT 웹/앱 채팅은 내 컴퓨터에서 명령을 실행할 수 없어서 이 플러그인을 쓸 수 없어요.)

## 방법 C. AI 없이 직접 실행

**macOS / Linux** (터미널)

```bash
curl -fsSL https://raw.githubusercontent.com/Andrew-Aparche/ablmOCexaone/main/skills/ablm-exaone-install/scripts/install.sh | bash
```

**Windows** (PowerShell)

```powershell
iwr https://raw.githubusercontent.com/Andrew-Aparche/ablmOCexaone/main/skills/ablm-exaone-install/scripts/install.ps1 -OutFile $env:TEMP\ablm-exaone.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File $env:TEMP\ablm-exaone.ps1
```

---

## 설치 후 사용법

1. **터미널을 완전히 닫았다가 새로 여세요.** (키와 PATH가 적용돼요)
2. 작업할 폴더로 이동해서 `opencode` 입력
3. OpenCode 안에서 `/models` → **K-EXAONE 2.5** 선택 확인
4. "이 폴더에 간단한 할 일 목록 웹페이지 만들어줘" 같은 요청으로 시작!

## 단계별로 따로 실행하기

```bash
bash install.sh check      # 설치 여부만 확인
bash install.sh install    # 1. OpenCode 설치
bash install.sh config     # 2. EXAONE 공급자 추가
bash install.sh key        # 3. API 키 저장 (키를 바꿀 때도 이것만 다시)
bash install.sh verify     # 4. 연결 확인
bash install.sh uninstall  # 저장한 키·쉘 설정 지우기
```

Windows는 `install.ps1 -Step check` 처럼 `-Step`을 붙여 쓰면 돼요.

## 키는 어디에 저장되나요?

| OS | 저장 위치 | OpenCode가 키를 읽는 방법 |
|---|---|---|
| macOS | 키체인 (`ablm-exaone-api-key`) | `~/.zshrc`에 추가된 한 줄이 터미널을 열 때 키체인에서 꺼내 `EXAONE_API_KEY`로 넘겨줌 (파일에는 키가 없음) |
| Windows | 사용자 환경변수 `EXAONE_API_KEY` | OpenCode가 환경변수를 바로 읽음 |
| Linux | 시스템 키링(`secret-tool`), 없으면 `~/.config/ablm-exaone/api-key` (권한 600) | `~/.bashrc`에 추가된 한 줄이 키를 불러옴 |

> Windows 사용자 환경변수는 내 계정에서만 보이지만 암호화되지는 않아요. 공용 PC에서는 사용 후 `-Step uninstall`로 지워주세요.
> macOS에서는 터미널에서 실행한 `opencode`가 키를 읽어요. Dock에서 바로 연 데스크탑 앱은 `.zshrc`를 읽지 않으니 CLI로 사용하세요.

## 추가되는 설정 (EXAONE 공식 문서 기준)

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "exaone/k-exaone_v2.5",
  "providers": {
    "exaone": {
      "package": "@opencode/ai/providers/openai-compatible",
      "name": "EXAONE",
      "settings": {
        "baseURL": "https://api.exaone.ai/v1",
        "apiKey": "{env:EXAONE_API_KEY}"
      },
      "models": {
        "k-exaone_v2.5": {
          "name": "K-EXAONE 2.5",
          "capabilities": {
            "tools": true,
            "input": ["text"],
            "output": ["text"],
            "temperature": true,
            "reasoning": { "supported": true }
          },
          "compatibility": { "reasoningField": "reasoning_content" },
          "body": { "reasoning_effort": "medium", "temperature": 1.0, "top_p": 0.95 }
        }
      }
    }
  }
}
```

## 참고 문서

- [EXAONE – 에이전트 시작하기](https://docs.exaone.ai/ko/docs/agent-start)
- [OpenCode – Providers](https://opencode.ai/docs/providers/)
- [OpenCode – Config](https://opencode.ai/docs/config/)

---

Made by **Studio ABLM (에이블램)** · MIT License
