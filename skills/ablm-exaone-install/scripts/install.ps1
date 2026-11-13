# =============================================================
#  에이블램엑사원설치 (Windows)
#  OpenCode 설치 → EXAONE 공급자 추가 → API 키 안전 저장 → 확인
#
#  사용법:
#    powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1 -Step all
#    -Step : all | check | install | config | key | verify | uninstall
# =============================================================
param(
  [ValidateSet('all', 'check', 'install', 'config', 'key', 'verify', 'uninstall')]
  [string]$Step = 'all'
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$EnvName    = 'EXAONE_API_KEY'
$ConfigDir  = Join-Path $env:USERPROFILE '.config\opencode'
$InstallDir = Join-Path $env:LOCALAPPDATA 'Programs\opencode'
$ModelId    = 'exaone/k-exaone_v2.5'
$ApiBase    = 'https://api.exaone.ai/v1'

# EXAONE 공식 문서(docs.exaone.ai/ko/docs/agent-start)의 OpenCode 설정
$ProviderJson = @'
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
'@

# ---------- 출력 도우미 ----------
function Write-Step($t) { Write-Host ""; Write-Host "==== $t ====" -ForegroundColor Cyan }
function Write-Ok($t)   { Write-Host "[OK] $t" -ForegroundColor Green }
function Write-Info($t) { Write-Host "  -> $t" }
function Write-Warn($t) { Write-Host "[주의] $t" -ForegroundColor Yellow }
function Stop-Fail($t)  { Write-Host "[실패] $t" -ForegroundColor Red; exit 1 }

# ---------- 1. OpenCode 설치 확인 / 설치 ----------
function Find-OpenCode {
  $c = Get-Command opencode -ErrorAction SilentlyContinue
  if ($c) { return $c.Source }
  $p = Join-Path $InstallDir 'opencode.exe'
  if (Test-Path $p) { return $p }
  return $null
}

function Test-Installed {
  $bin = Find-OpenCode
  if ($bin) {
    $ver = ''
    try { $ver = (& $bin --version 2>$null | Select-Object -First 1) } catch {}
    Write-Ok "OpenCode가 설치되어 있어요: $bin $(if ($ver) { "($ver)" })"
    return $true
  }
  return $false
}

function Invoke-Check {
  Write-Step 'OpenCode 설치 확인'
  if (-not (Test-Installed)) { Write-Warn 'OpenCode가 아직 설치되어 있지 않아요.' }
}

function Invoke-Install {
  Write-Step '1/4 OpenCode 설치 확인'
  if (Test-Installed) { Write-Info '이미 설치되어 있어서 설치는 건너뛸게요.'; return }

  Write-Info 'OpenCode가 없어서 공식 파일을 내려받아 설치할게요.'
  $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
  $url  = "https://opencode.ai/update/api/latest/cli/opencode/opencode-windows-$arch.zip"
  $id   = [guid]::NewGuid().ToString('N')
  $zip  = Join-Path $env:TEMP "opencode-$id.zip"
  $dir  = Join-Path $env:TEMP "opencode-$id"

  try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath $dir -Force
    $exe = Get-ChildItem -Path $dir -Recurse -Filter 'opencode.exe' | Select-Object -First 1
    if (-not $exe) { Stop-Fail '내려받은 파일 안에서 opencode.exe를 찾지 못했어요.' }
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    Copy-Item $exe.FullName (Join-Path $InstallDir 'opencode.exe') -Force
  } catch {
    Stop-Fail "OpenCode 설치 중 오류가 났어요: $($_.Exception.Message)"
  } finally {
    Remove-Item $zip -Force -ErrorAction SilentlyContinue
    Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
  }

  # 사용자 PATH에 추가 (다음에 여는 터미널부터 적용)
  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  if (-not $userPath) { $userPath = '' }
  if (($userPath -split ';') -notcontains $InstallDir) {
    $newPath = (($userPath.TrimEnd(';')) + ';' + $InstallDir).TrimStart(';')
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    Write-Ok "PATH에 추가했어요: $InstallDir"
  }
  $env:Path = "$env:Path;$InstallDir"
  Write-Ok "OpenCode 설치 완료: $(Join-Path $InstallDir 'opencode.exe')"
}

# ---------- 2. EXAONE 공급자 추가 ----------
function Set-Prop($obj, [string]$name, $value) {
  if ($obj.PSObject.Properties[$name]) { $obj.$name = $value }
  else { $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value }
}

function Invoke-Config {
  Write-Step '2/4 EXAONE 공급자 추가'
  New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
  $target = Join-Path $ConfigDir 'opencode.json'
  $jsonc  = Join-Path $ConfigDir 'opencode.jsonc'
  if (-not (Test-Path $target) -and (Test-Path $jsonc)) { $target = $jsonc }

  $add = $ProviderJson | ConvertFrom-Json
  $cfg = $null

  if (Test-Path $target) {
    $backup = "$target.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $target $backup -Force
    Write-Ok "기존 설정을 백업했어요: $backup"
    $raw = [IO.File]::ReadAllText($target)
    if ($raw.Trim()) {
      try { $cfg = $raw | ConvertFrom-Json }
      catch { Stop-Fail "기존 설정 파일($target)에 주석 등이 있어서 자동으로 고칠 수 없어요. 파일은 건드리지 않았어요." }
    }
  }
  if (-not $cfg) { $cfg = New-Object PSObject }

  if (-not $cfg.PSObject.Properties['$schema']) { Set-Prop $cfg '$schema' $add.'$schema' }
  if (-not $cfg.PSObject.Properties['providers'] -or -not $cfg.providers) {
    Set-Prop $cfg 'providers' (New-Object PSObject)
  }
  Set-Prop $cfg.providers 'exaone' $add.providers.exaone
  Set-Prop $cfg 'model' $add.model

  $out = $cfg | ConvertTo-Json -Depth 32
  [IO.File]::WriteAllText($target, $out + "`n", (New-Object System.Text.UTF8Encoding($false)))
  Write-Ok "EXAONE 공급자를 추가했어요: $target"
  Write-Info "기본 모델: $ModelId"
}

# ---------- 3. API 키 안전 저장 ----------
function Read-KeyDialog {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  [System.Windows.Forms.Application]::EnableVisualStyles()

  $form = New-Object System.Windows.Forms.Form
  $form.Text = '에이블램 엑사원 설치'
  $form.ClientSize = New-Object System.Drawing.Size(440, 150)
  $form.StartPosition = 'CenterScreen'
  $form.FormBorderStyle = 'FixedDialog'
  $form.MaximizeBox = $false
  $form.MinimizeBox = $false
  $form.TopMost = $true

  $label = New-Object System.Windows.Forms.Label
  $label.Text = "EXAONE API 키를 붙여넣고 [저장]을 눌러주세요.`n(입력 내용은 ●로 가려져요)"
  $label.Location = New-Object System.Drawing.Point(16, 14)
  $label.Size = New-Object System.Drawing.Size(410, 40)
  $form.Controls.Add($label)

  $box = New-Object System.Windows.Forms.TextBox
  $box.UseSystemPasswordChar = $true
  $box.Location = New-Object System.Drawing.Point(16, 62)
  $box.Size = New-Object System.Drawing.Size(408, 24)
  $form.Controls.Add($box)

  $okBtn = New-Object System.Windows.Forms.Button
  $okBtn.Text = '저장'
  $okBtn.Location = New-Object System.Drawing.Point(254, 104)
  $okBtn.Size = New-Object System.Drawing.Size(80, 30)
  $okBtn.DialogResult = [System.Windows.Forms.DialogResult]::OK
  $form.Controls.Add($okBtn)
  $form.AcceptButton = $okBtn

  $cancelBtn = New-Object System.Windows.Forms.Button
  $cancelBtn.Text = '취소'
  $cancelBtn.Location = New-Object System.Drawing.Point(344, 104)
  $cancelBtn.Size = New-Object System.Drawing.Size(80, 30)
  $cancelBtn.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
  $form.Controls.Add($cancelBtn)
  $form.CancelButton = $cancelBtn

  $form.Add_Shown({ $form.Activate(); $box.Focus() })
  $result = $form.ShowDialog()
  $text = $box.Text
  $form.Dispose()
  if ($result -ne [System.Windows.Forms.DialogResult]::OK) { return $null }
  return $text
}

function Invoke-Key {
  Write-Step '3/4 API 키 안전하게 저장'
  Write-Info '보안 입력 창이 뜨면 EXAONE API 키를 붙여넣어 주세요. (채팅창에는 붙여넣지 마세요!)'
  $key = $null
  try { $key = Read-KeyDialog }
  catch {
    # 입력 창을 띄울 수 없는 환경이면 터미널에서 가려진 입력으로 받기
    try {
      $sec = Read-Host -AsSecureString 'EXAONE API 키를 붙여넣고 Enter (화면에 안 보여요)'
      $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
      try { $key = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
      finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
    } catch { $key = $null }
  }
  if ($key) { $key = ($key -replace '\s', '') }
  if (-not $key) {
    Stop-Fail "키가 입력되지 않았어요(취소했거나 입력 창을 띄울 수 없는 환경이에요). 본인 PowerShell에서 'install.ps1 -Step key'를 직접 실행해 주세요."
  }

  # 사용자 환경변수(본인 계정 전용)에 저장. 프로젝트 파일에는 저장되지 않아요.
  [Environment]::SetEnvironmentVariable($EnvName, $key, 'User')
  Set-Item -Path "Env:$EnvName" -Value $key
  Remove-Variable key -ErrorAction SilentlyContinue
  Write-Ok "사용자 환경변수 $EnvName 에 저장했어요. (설정 > 시스템 > 정보 > 고급 시스템 설정 > 환경 변수에서 확인 가능)"
}

# ---------- 4. 확인 ----------
function Invoke-Verify {
  Write-Step '4/4 연결 확인'
  $found = $null
  foreach ($f in @((Join-Path $ConfigDir 'opencode.json'), (Join-Path $ConfigDir 'opencode.jsonc'))) {
    if ((Test-Path $f) -and (Select-String -Path $f -Pattern '"exaone"' -Quiet)) { $found = $f }
  }
  if ($found) { Write-Ok "설정 파일에 EXAONE 공급자가 있어요: $found" }
  else { Write-Warn "설정 파일에 EXAONE 공급자가 없어요. -Step config 를 다시 해주세요." }

  $key = [Environment]::GetEnvironmentVariable($EnvName, 'User')
  if (-not $key) { Write-Warn "저장된 API 키를 찾지 못했어요. -Step key 를 다시 해주세요."; return }
  Write-Ok '저장된 API 키를 찾았어요. (값은 표시하지 않아요)'

  $code = 0
  try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $r = Invoke-WebRequest -Uri "$ApiBase/models" -Headers @{ Authorization = "Bearer $key" } -UseBasicParsing -TimeoutSec 15
    $code = [int]$r.StatusCode
  } catch {
    if ($_.Exception.Response) { try { $code = [int]$_.Exception.Response.StatusCode } catch { $code = 0 } }
  }
  Remove-Variable key -ErrorAction SilentlyContinue

  switch ($code) {
    200     { Write-Ok 'EXAONE 서버에서 키 인증에 성공했어요!' }
    401     { Write-Host "[실패] 키 인증 실패(401): 키가 틀렸거나 만료된 것 같아요. -Step key 를 다시 해주세요." -ForegroundColor Red }
    403     { Write-Host "[실패] 키 인증 실패(403): 키 권한을 확인해 주세요." -ForegroundColor Red }
    default { Write-Warn "자동 확인은 못 했어요(응답 코드 $code). OpenCode를 실행해서 직접 말을 걸어 확인해 주세요." }
  }
}

function Show-Finish {
  Write-Host ''
  Write-Host '설치가 끝났어요!' -ForegroundColor Green
  Write-Info '1) 터미널(PowerShell/명령 프롬프트)을 완전히 닫았다가 새로 열어주세요.'
  Write-Info '2) 작업할 폴더로 이동해서 opencode 를 입력하세요.'
  Write-Info "3) OpenCode 안에서 /models → 'K-EXAONE 2.5'가 선택되어 있는지 확인하세요."
}

function Invoke-Uninstall {
  Write-Step '되돌리기'
  [Environment]::SetEnvironmentVariable($EnvName, $null, 'User')
  Remove-Item -Path "Env:$EnvName" -ErrorAction SilentlyContinue
  Write-Ok "사용자 환경변수 $EnvName 를 지웠어요."
  Write-Info "opencode.json 원본은 $ConfigDir 안의 .bak-날짜 파일로 남아 있어요. 필요하면 그 파일로 되돌리세요."
}

switch ($Step) {
  'check'     { Invoke-Check }
  'install'   { Invoke-Install }
  'config'    { Invoke-Config }
  'key'       { Invoke-Key }
  'verify'    { Invoke-Verify }
  'uninstall' { Invoke-Uninstall }
  'all'       { Invoke-Install; Invoke-Config; Invoke-Key; Invoke-Verify; Show-Finish }
}
