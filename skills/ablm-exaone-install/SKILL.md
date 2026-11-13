---
name: ablm-exaone-install
description: 사용자가 "에이블램엑사원설치"라고 하거나 OpenCode에 EXAONE(엑사원, K-EXAONE) 모델을 붙이고 싶다고 할 때 사용. OpenCode CLI 설치 확인/설치 → opencode.json에 EXAONE 공급자 추가 → API 키를 안전하게 저장(Windows는 사용자 환경변수, macOS는 키체인) → 연결 확인까지 자동으로 진행한다.
---

# 에이블램엑사원설치

OpenCode(오픈소스 코딩 에이전트)에 LG EXAONE 모델(`exaone/k-exaone_v2.5`)을 연결하는 자동 설치 스킬이에요.
사용자는 대부분 **코딩 초보**예요. 각 단계를 시작할 때 무엇을 하는지 한 문장으로 쉽게 알려주고, 끝나면 결과를 한 줄로 알려주세요.

## 🔒 가장 중요한 규칙: API 키

- **API 키를 채팅에 붙여넣으라고 절대 요청하지 마세요.** 채팅에 넣은 키는 대화 기록에 남아요.
- 키 입력은 스크립트가 띄우는 **보안 입력 창**(입력 내용이 ●로 가려짐)에서만 받아요.
- 사용자가 실수로 채팅에 키를 붙여넣었다면, 키를 다시 출력하거나 사용하지 말고 이렇게 안내하세요:
  "채팅에 올린 키는 노출된 것으로 보는 게 안전해요. EXAONE 콘솔에서 키를 새로 발급받은 다음, 잠시 후 뜨는 입력 창에 새 키를 넣어주세요."
- 명령어에 키를 직접 넣어서 실행하지 마세요. (`export EXAONE_API_KEY=...` 같은 명령 금지)

## 0단계: 준비

1. 이 스킬 폴더의 위치를 확인해요. (스킬을 불러올 때 표시되는 base directory) 아래에서는 이 위치를 `SKILL_DIR`이라고 부를게요.
2. 운영체제를 확인해요.
   - `uname -s` 결과가 `Darwin` → **macOS**
   - `Linux` → **Linux**
   - 결과가 `MINGW…`, `MSYS…`, `CYGWIN…`이거나 `uname`이 없으면 → **Windows**

실행할 명령어:

- macOS / Linux:
  ```bash
  bash "SKILL_DIR/scripts/install.sh" <단계>
  ```
- Windows (Git Bash, PowerShell 어디서든):
  ```bash
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "SKILL_DIR/scripts/install.ps1" -Step <단계>
  ```

`<단계>`에는 아래 순서대로 `install` → `config` → `key` → `verify`를 넣어요. 한 단계씩 실행해야 결과를 확인하면서 사용자에게 설명할 수 있어요.

## 1단계: OpenCode 설치 확인 → 없으면 설치 (`install`)

- 사용자에게: "먼저 컴퓨터에 OpenCode가 깔려 있는지 확인하고, 없으면 설치할게요."
- `install`을 실행해요. 이미 설치되어 있으면 건너뛰어요.
- macOS/Linux는 공식 설치 스크립트를 사용해요. Windows는 공식 zip 파일을 받아서 `%LOCALAPPDATA%\Programs\opencode`에 설치하고 PATH에 추가해요.
- 실패하면 오류 메시지를 쉽게 풀어서 설명하고 멈춰요. (인터넷 연결, 회사 보안 프로그램 등)

## 2단계: EXAONE 공급자 추가 (`config`)

- 사용자에게: "OpenCode 설정 파일에 EXAONE을 '공급자'로 등록할게요. 원래 설정은 백업해 둘게요."
- `config`를 실행해요. 전역 설정 파일 `~/.config/opencode/opencode.json`에 추가되므로 어느 폴더에서든 EXAONE을 쓸 수 있어요.
- 기존 설정은 그대로 두고 `providers.exaone`만 추가하고, 기본 모델을 `exaone/k-exaone_v2.5`로 바꿔요. 원본은 `.bak-날짜` 파일로 백업돼요.
- 기존 파일에 주석이 있어서 읽지 못했다는 오류가 나면, 파일을 덮어쓰지 말고 사용자에게 알려요.

## 3단계: API 키 안전하게 저장 (`key`)

- 사용자에게 먼저 이렇게 말해요:
  "이제 화면에 **'에이블램 엑사원 설치' 입력 창**이 떠요. EXAONE API 키를 거기에 붙여넣고 [저장]을 눌러주세요. 채팅창에는 붙여넣지 마세요!"
- 그다음 `key`를 실행해요. 사용자가 입력을 마칠 때까지 기다려요. (명령이 오래 걸릴 수 있으니 시간 제한을 넉넉히, 예: 10분)
- 저장되는 곳:
  - **macOS**: 키체인(서비스 이름 `ablm-exaone-api-key`). `~/.zshrc`, `~/.bash_profile`에는 키 자체가 아니라 "키체인에서 키를 꺼내 오는 한 줄"만 추가돼요.
  - **Windows**: 사용자 환경변수 `EXAONE_API_KEY` (프로젝트 파일에는 키가 저장되지 않아요)
  - **Linux**: 시스템 키링(`secret-tool`)이 있으면 키링에, 없으면 본인만 읽을 수 있는 파일(`~/.config/ablm-exaone/api-key`, 권한 600)
- 입력 창이 뜨지 않는 환경이라는 오류가 나면(원격 접속 등), 사용자에게 **본인의 터미널에서 직접** 아래 명령을 실행하라고 안내해요:
  - macOS/Linux: `bash "SKILL_DIR/scripts/install.sh" key`
  - Windows: `powershell -ExecutionPolicy Bypass -File "SKILL_DIR\scripts\install.ps1" -Step key`
- 사용자가 취소하면 다시 할지 물어봐요.

## 4단계: 연결 확인 (`verify`)

- 사용자에게: "마지막으로 설정과 키가 제대로 들어갔는지 확인할게요."
- `verify`를 실행해요. 키 값은 화면에 출력되지 않아요.
- 결과 해석:
  - ✅ 키 인증 성공 → 완료
  - ❌ 401/403 → "키가 틀렸거나 만료된 것 같아요. `key` 단계를 다시 해볼게요." 하고 3단계를 다시 진행
  - ⚠️ 그 밖의 코드 → 자동 확인만 실패한 거예요. 실제로 OpenCode를 실행해서 확인하라고 안내해요

## 마무리 안내 (사용자에게 그대로 전달)

설치가 끝나면 아래 내용을 쉽게 정리해서 알려주세요.

1. **터미널을 완전히 닫았다가 새로 열어주세요.** (그래야 키와 PATH가 적용돼요)
2. 작업할 폴더로 이동해서 `opencode`를 입력해요.
3. OpenCode 안에서 `/models`를 입력하고 **EXAONE / K-EXAONE 2.5**가 선택되어 있는지 확인해요.
4. 첫 요청 예시: "이 폴더에 간단한 할 일 목록 웹페이지를 만들어줘"

되돌리고 싶다면 `uninstall` 단계를 실행하세요. 저장한 키와 쉘 설정 줄이 지워지고, opencode.json 백업 파일 위치를 알려줘요.
