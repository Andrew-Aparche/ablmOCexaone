#!/usr/bin/env bash
# =============================================================
#  에이블램엑사원설치 (macOS / Linux)
#  OpenCode 설치 → EXAONE 공급자 추가 → API 키 안전 저장 → 확인
#
#  사용법:  bash install.sh [all|check|install|config|key|verify|uninstall]
#  (아무것도 안 쓰면 all = 전체 자동 진행)
# =============================================================
set -euo pipefail

SERVICE="ablm-exaone-api-key"          # 키체인/키링에 저장되는 이름
ENV_NAME="EXAONE_API_KEY"              # OpenCode가 읽는 환경변수 이름
CONFIG_DIR="$HOME/.config/opencode"
MODEL_ID="exaone/k-exaone_v2.5"
LINUX_KEY_FILE="$HOME/.config/ablm-exaone/api-key"
API_BASE="https://api.exaone.ai/v1"
OS="$(uname -s)"
MARK_BEGIN="# >>> ablm-exaone >>>"
MARK_END="# <<< ablm-exaone <<<"

# EXAONE 공식 문서(docs.exaone.ai/ko/docs/agent-start)의 OpenCode 설정
PROVIDER_JSON='{
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
}'

# ---------- 출력 도우미 ----------
step() { printf '\n==== %s ====\n' "$*"; }
ok()   { printf '✅ %s\n' "$*"; }
info() { printf '👉 %s\n' "$*"; }
warn() { printf '⚠️  %s\n' "$*"; }
fail() { printf '❌ %s\n' "$*" >&2; exit 1; }

# ---------- 1. OpenCode 설치 확인 / 설치 ----------
find_opencode() {
  if command -v opencode >/dev/null 2>&1; then command -v opencode; return 0; fi
  local p
  for p in "$HOME/.opencode/bin/opencode" "$HOME/.local/bin/opencode" \
           "/opt/homebrew/bin/opencode" "/usr/local/bin/opencode"; do
    if [ -x "$p" ]; then echo "$p"; return 0; fi
  done
  return 1
}

is_installed() {
  local bin ver
  if bin="$(find_opencode)"; then
    ver="$("$bin" --version 2>/dev/null | head -n1 || true)"
    ok "OpenCode가 설치되어 있어요: $bin ${ver:+($ver)}"
    return 0
  fi
  return 1
}

cmd_check() {
  step "OpenCode 설치 확인"
  is_installed || warn "OpenCode가 아직 설치되어 있지 않아요."
}

cmd_install() {
  step "1/4 OpenCode 설치 확인"
  if is_installed; then info "이미 설치되어 있어서 설치는 건너뛸게요."; return 0; fi
  info "OpenCode가 없어서 공식 설치 스크립트로 설치할게요."
  command -v curl >/dev/null 2>&1 || fail "curl이 없어요. curl을 먼저 설치해 주세요."
  curl -fsSL https://opencode.ai/v2/install | bash
  if is_installed; then
    ok "OpenCode 설치 완료!"
  else
    warn "설치는 끝났지만 지금 터미널에서는 아직 opencode를 찾지 못했어요."
    info "터미널을 새로 열면 인식돼요."
  fi
}

# ---------- 2. EXAONE 공급자 추가 ----------
merge_with_jxa() {   # macOS 기본 내장 JavaScript (추가 설치 불필요)
  local target="$1" js
  js="$(mktemp -t ablmexaone).js"
  cat > "$js" <<'JXA'
ObjC.import('Foundation');
function run(argv) {
  var path = argv[0], add = JSON.parse(argv[1]), cfg = {};
  var fm = $.NSFileManager.defaultManager;
  if (fm.fileExistsAtPath(path)) {
    var s = $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null);
    var txt = s.isNil() ? '' : ObjC.unwrap(s);
    if (txt.replace(/\s/g, '').length > 0) {
      try { cfg = JSON.parse(txt); } catch (e) { return 'PARSE_ERROR'; }
    }
  }
  if (!cfg['$schema']) cfg['$schema'] = add['$schema'];
  if (!cfg.providers || typeof cfg.providers !== 'object') cfg.providers = {};
  cfg.providers.exaone = add.providers.exaone;
  cfg.model = add.model;
  var out = $(JSON.stringify(cfg, null, 2) + '\n');
  var okw = out.writeToFileAtomicallyEncodingError(path, true, $.NSUTF8StringEncoding, null);
  return okw ? 'OK' : 'WRITE_ERROR';
}
JXA
  local res
  res="$(osascript -l JavaScript "$js" "$target" "$PROVIDER_JSON" 2>&1 || true)"
  rm -f "$js"
  echo "$res"
}

merge_with_python() {
  python3 - "$1" "$PROVIDER_JSON" <<'PY'
import json, os, sys
path, add = sys.argv[1], json.loads(sys.argv[2])
cfg = {}
if os.path.exists(path):
    txt = open(path, encoding="utf-8").read()
    if txt.strip():
        try:
            cfg = json.loads(txt)
        except Exception:
            print("PARSE_ERROR"); sys.exit(0)
cfg.setdefault("$schema", add["$schema"])
if not isinstance(cfg.get("providers"), dict):
    cfg["providers"] = {}
cfg["providers"]["exaone"] = add["providers"]["exaone"]
cfg["model"] = add["model"]
tmp = path + ".tmp"
with open(tmp, "w", encoding="utf-8") as f:
    json.dump(cfg, f, ensure_ascii=False, indent=2); f.write("\n")
os.replace(tmp, path)
print("OK")
PY
}

merge_with_node() {
  node - "$1" "$PROVIDER_JSON" <<'NODE'
const fs = require('fs');
const [path, addRaw] = process.argv.slice(2);
const add = JSON.parse(addRaw);
let cfg = {};
if (fs.existsSync(path)) {
  const txt = fs.readFileSync(path, 'utf8');
  if (txt.trim()) { try { cfg = JSON.parse(txt); } catch (e) { console.log('PARSE_ERROR'); process.exit(0); } }
}
if (!cfg['$schema']) cfg['$schema'] = add['$schema'];
if (!cfg.providers || typeof cfg.providers !== 'object') cfg.providers = {};
cfg.providers.exaone = add.providers.exaone;
cfg.model = add.model;
fs.writeFileSync(path + '.tmp', JSON.stringify(cfg, null, 2) + '\n');
fs.renameSync(path + '.tmp', path);
console.log('OK');
NODE
}

cmd_config() {
  step "2/4 EXAONE 공급자 추가"
  mkdir -p "$CONFIG_DIR"
  local target="$CONFIG_DIR/opencode.json"
  if [ ! -f "$target" ] && [ -f "$CONFIG_DIR/opencode.jsonc" ]; then
    target="$CONFIG_DIR/opencode.jsonc"
  fi

  if [ -f "$target" ]; then
    local backup="$target.bak-$(date +%Y%m%d-%H%M%S)"
    cp "$target" "$backup"
    ok "기존 설정을 백업했어요: $backup"
  fi

  local res
  if [ "$OS" = "Darwin" ]; then
    res="$(merge_with_jxa "$target")"
  elif command -v python3 >/dev/null 2>&1; then
    res="$(merge_with_python "$target")"
  elif command -v node >/dev/null 2>&1; then
    res="$(merge_with_node "$target")"
  else
    fail "설정 파일을 수정할 도구(python3 또는 node)가 없어요."
  fi

  case "$res" in
    *OK*)          ok "EXAONE 공급자를 추가했어요: $target"
                   info "기본 모델: $MODEL_ID" ;;
    *PARSE_ERROR*) fail "기존 설정 파일($target)에 주석 등이 있어서 자동으로 고칠 수 없어요. 파일은 건드리지 않았어요." ;;
    *)             fail "설정 파일 저장에 실패했어요: $res" ;;
  esac
}

# ---------- 3. API 키 안전 저장 ----------
remove_rc_block() {
  local rc="$1"
  [ -f "$rc" ] || return 0
  if grep -qF "$MARK_BEGIN" "$rc"; then
    sed -i.ablmbak "/$MARK_BEGIN/,/$MARK_END/d" "$rc" && rm -f "$rc.ablmbak"
  fi
}

add_rc_block() {   # 쉘 시작 시 키를 꺼내오는 "한 줄"만 추가 (키 자체는 저장 안 함)
  local loader="$1" rc
  for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile"; do
    # macOS는 zsh/bash_profile, Linux는 bashrc 중심. 없는 파일은 zsh 기본값만 만듦
    if [ ! -f "$rc" ]; then
      if [ "$OS" = "Darwin" ] && [ "$rc" = "$HOME/.zshrc" ]; then touch "$rc"; else continue; fi
    fi
    remove_rc_block "$rc"
    printf '\n%s\n%s\n%s\n' "$MARK_BEGIN" "$loader" "$MARK_END" >> "$rc"
    ok "쉘 설정에 키 불러오기 줄을 추가했어요: $rc"
  done
}

ask_key_mac() {
  osascript <<'OSA' 2>/dev/null
set dlg to display dialog "EXAONE API 키를 붙여넣고 [저장]을 눌러주세요." & return & "(입력 내용은 화면에 보이지 않아요)" default answer "" with hidden answer with title "에이블램 엑사원 설치" buttons {"취소", "저장"} default button "저장" cancel button "취소" with icon note
return text returned of dlg
OSA
}

ask_key_linux() {
  if command -v zenity >/dev/null 2>&1 && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
    zenity --password --title="에이블램 엑사원 설치" 2>/dev/null
  elif [ -r /dev/tty ] && [ -w /dev/tty ] && (exec </dev/tty) 2>/dev/null; then
    local k
    printf 'EXAONE API 키를 붙여넣고 Enter (화면에 안 보여요): ' > /dev/tty
    IFS= read -rs k < /dev/tty; printf '\n' > /dev/tty
    printf '%s' "$k"
  else
    return 1
  fi
}

cmd_key() {
  step "3/4 API 키 안전하게 저장"
  info "보안 입력 창이 뜨면 EXAONE API 키를 붙여넣어 주세요. (채팅창에는 붙여넣지 마세요!)"
  local key=""
  if [ "$OS" = "Darwin" ]; then
    key="$(ask_key_mac || true)"
  else
    key="$(ask_key_linux || true)"
  fi
  key="$(printf '%s' "$key" | tr -d '[:space:]')"
  if [ -z "$key" ]; then
    fail "키가 입력되지 않았어요(취소했거나 입력 창을 띄울 수 없는 환경이에요). 본인 터미널에서 'bash install.sh key'를 직접 실행해 주세요."
  fi

  if [ "$OS" = "Darwin" ]; then
    security delete-generic-password -a "$USER" -s "$SERVICE" >/dev/null 2>&1 || true
    security add-generic-password -a "$USER" -s "$SERVICE" -l "EXAONE API Key (ablm)" -w "$key" \
      || fail "키체인 저장에 실패했어요."
    ok "macOS 키체인에 저장했어요. (키체인 접근 앱에서 '$SERVICE'로 확인 가능)"
    add_rc_block "export $ENV_NAME=\"\$(security find-generic-password -a \"\$USER\" -s $SERVICE -w 2>/dev/null)\""
  else
    if command -v secret-tool >/dev/null 2>&1 && \
       printf '%s' "$key" | secret-tool store --label="EXAONE API Key (ablm)" service "$SERVICE" 2>/dev/null; then
      ok "시스템 키링에 저장했어요."
      add_rc_block "export $ENV_NAME=\"\$(secret-tool lookup service $SERVICE 2>/dev/null)\""
    else
      mkdir -p "$(dirname "$LINUX_KEY_FILE")"
      ( umask 077; printf '%s' "$key" > "$LINUX_KEY_FILE" )
      chmod 600 "$LINUX_KEY_FILE"
      ok "본인만 읽을 수 있는 파일에 저장했어요: $LINUX_KEY_FILE (권한 600)"
      add_rc_block "export $ENV_NAME=\"\$(cat \"$LINUX_KEY_FILE\" 2>/dev/null)\""
    fi
  fi
  unset key
}

# ---------- 4. 확인 ----------
read_saved_key() {
  if [ "$OS" = "Darwin" ]; then
    security find-generic-password -a "$USER" -s "$SERVICE" -w 2>/dev/null || true
  elif command -v secret-tool >/dev/null 2>&1 && secret-tool lookup service "$SERVICE" >/dev/null 2>&1; then
    secret-tool lookup service "$SERVICE" 2>/dev/null || true
  elif [ -f "$LINUX_KEY_FILE" ]; then
    cat "$LINUX_KEY_FILE"
  fi
}

cmd_verify() {
  step "4/4 연결 확인"
  local cfg="" f
  for f in "$CONFIG_DIR/opencode.json" "$CONFIG_DIR/opencode.jsonc"; do
    if [ -f "$f" ] && grep -q '"exaone"' "$f"; then cfg="$f"; fi
  done
  if [ -n "$cfg" ]; then ok "설정 파일에 EXAONE 공급자가 있어요: $cfg"; else warn "설정 파일에 EXAONE 공급자가 없어요. 'config' 단계를 다시 해주세요."; fi

  local key; key="$(read_saved_key)"
  if [ -z "$key" ]; then warn "저장된 API 키를 찾지 못했어요. 'key' 단계를 다시 해주세요."; return 0; fi
  ok "저장된 API 키를 찾았어요. (값은 표시하지 않아요)"

  if command -v curl >/dev/null 2>&1; then
    local code
    # 키가 명령줄(프로세스 목록)에 보이지 않도록 표준입력으로 헤더 전달
    code="$(printf 'header = "Authorization: Bearer %s"\n' "$key" | \
            curl -s -o /dev/null -w '%{http_code}' --max-time 15 -K - "$API_BASE/models" || echo 000)"
    case "$code" in
      200)     ok "EXAONE 서버에서 키 인증에 성공했어요!" ;;
      401|403) printf '❌ 키 인증 실패(%s): 키가 틀렸거나 만료된 것 같아요. key 단계를 다시 해주세요.\n' "$code" ;;
      *)       warn "자동 확인은 못 했어요(응답 코드 $code). OpenCode를 실행해서 직접 말을 걸어 확인해 주세요." ;;
    esac
  fi
  unset key
}

finish_message() {
  printf '\n🎉 설치가 끝났어요!\n'
  info "1) 터미널을 완전히 닫았다가 새로 열어주세요."
  info "2) 작업할 폴더로 이동해서 opencode 를 입력하세요."
  info "3) OpenCode 안에서 /models → 'K-EXAONE 2.5'가 선택되어 있는지 확인하세요."
}

cmd_uninstall() {
  step "되돌리기"
  if [ "$OS" = "Darwin" ]; then
    security delete-generic-password -a "$USER" -s "$SERVICE" >/dev/null 2>&1 && ok "키체인에서 키를 지웠어요." || true
  else
    command -v secret-tool >/dev/null 2>&1 && secret-tool clear service "$SERVICE" 2>/dev/null || true
    rm -f "$LINUX_KEY_FILE"
    ok "저장된 키를 지웠어요."
  fi
  local rc
  for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile"; do remove_rc_block "$rc"; done
  ok "쉘 설정에서 키 불러오기 줄을 지웠어요."
  info "opencode.json 원본은 $CONFIG_DIR 안의 .bak-날짜 파일로 남아 있어요. 필요하면 그 파일로 되돌리세요."
}

case "${1:-all}" in
  check)     cmd_check ;;
  install)   cmd_install ;;
  config)    cmd_config ;;
  key)       cmd_key ;;
  verify)    cmd_verify ;;
  uninstall) cmd_uninstall ;;
  all)       cmd_install; cmd_config; cmd_key; cmd_verify; finish_message ;;
  *)         echo "사용법: bash install.sh [all|check|install|config|key|verify|uninstall]"; exit 1 ;;
esac
