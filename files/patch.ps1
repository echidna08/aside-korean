# Aside 설정 화면 한글패치 (Windows PowerShell 5.1 이상, 설치 필요 없음)
#
#   patch.ps1 install     고정 위치에 복사 + 10분마다 자동 재적용 등록 + 적용
#   patch.ps1 uninstall   자동 재적용 끄기 + 영어 원본으로 되돌리기
#   patch.ps1 apply       설치된 모든 버전에 한글 적용 (이미 적용된 건 건너뜀)
#   patch.ps1 revert      영어 원본으로 되돌리기 + 원본과 같은지 검사
#   patch.ps1 status      지금 상태 보기
#   -quiet                출력 없이 (자동 재적용용, 오류는 error.log 에)
#
# 설정 화면 청크(AsideAgentManager\<버전>\assets\*.js)의 key:"English" 문자열만 ko.json 대로 바꾼다.
# 영어 원본은 %LOCALAPPDATA%\AsideKoreanPatch\backup\<버전>\ 에 보관한다.
param([string]$cmd = "status", [switch]$quiet)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [Text.Encoding]::UTF8
Add-Type -AssemblyName System.Web.Extensions

$HERE = $PSScriptRoot
$AM_ROOT = if ($env:AKP_ROOT) { $env:AKP_ROOT } else { Join-Path $env:LOCALAPPDATA "Aside\User Data\AsideAgentManager" }
$HOME_DIR = if ($env:AKP_HOME) { $env:AKP_HOME } else { Join-Path $env:LOCALAPPDATA "AsideKoreanPatch" }
$BACKUP = Join-Path $HOME_DIR "backup"
$STATE_PATH = Join-Path $HOME_DIR "state.json"
$TASK_NAME = "AsideKoreanPatch"
$UTF8 = New-Object Text.UTF8Encoding($false)
$JSON = New-Object Web.Script.Serialization.JavaScriptSerializer
$JSON.MaxJsonLength = 64MB

$KEYS = 'children|title|description|label|placeholder|"aria-label"|tooltip|message|subtitle|heading|text|confirmLabel|cancelLabel|emptyMessage|helperText|hint|caption|badge|ctaLabel|buttonLabel|confirmText|alt'
$STR_RE = New-Object Regex ('(?<![\w$.])(' + $KEYS + '):"((?:[^"\\]|\\.)*)"')
$ROUTE_RE = New-Object Regex 'import\("\./([\w.-]+\.js)"\),__vite__mapDeps\(\[([\d,]*)\]\)\).{0,40}?=\w+\("([^"]+)"\)'
$HANGUL = New-Object Regex '[가-힣]'

function Say($s) { if (-not $quiet) { Write-Host $s } }
function ReadText($p) { [IO.File]::ReadAllText($p, $UTF8) }
function WriteText($p, $s) { [IO.File]::WriteAllText($p, $s, $UTF8) }
function Sha($p) { (Get-FileHash -Algorithm SHA256 -LiteralPath $p).Hash.ToLower() }

function LoadJson($p) {
    if (Test-Path -LiteralPath $p) { try { return $JSON.DeserializeObject((ReadText $p)) } catch {} }
    return @{}
}

function Get-Versions {
    if (-not (Test-Path -LiteralPath $AM_ROOT)) { return @() }
    @(Get-ChildItem -LiteralPath $AM_ROOT -Directory |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "manifest.json") } |
        Sort-Object { try { [version]$_.Name } catch { [version]"0.0" } } |
        ForEach-Object { $_.Name })
}

# 설정 라우트만 쓰는 청크 (설정 밖 라우트도 쓰는 공용 청크는 제외)
function Get-SettingsFiles($assets) {
    $main = Get-ChildItem -LiteralPath $assets -Filter "extension-main-*.js" | Select-Object -First 1
    if (-not $main) { return @() }
    $s = ReadText $main.FullName
    $m = [regex]::Match($s, 'm\.f=(\[.*?\])\)')
    if (-not $m.Success) { return @() }
    $depNames = @([regex]::Matches($m.Groups[1].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value.Split("/")[-1] })
    $inside = New-Object 'Collections.Generic.HashSet[string]'
    $outside = New-Object 'Collections.Generic.HashSet[string]'
    foreach ($r in $ROUTE_RE.Matches($s)) {
        $set = $outside
        if ($r.Groups[3].Value.Contains("settings")) { $set = $inside }
        [void]$set.Add($r.Groups[1].Value)
        foreach ($i in $r.Groups[2].Value.Split(",")) { if ($i) { [void]$set.Add($depNames[[int]$i]) } }
    }
    @($inside | Where-Object { -not $outside.Contains($_) -and (Test-Path -LiteralPath (Join-Path $assets $_)) } | Sort-Object)
}

function Invoke-Apply {
    $ko = LoadJson (Join-Path $HERE "ko.json")
    $state = LoadJson $STATE_PATH
    $script:total = 0
    foreach ($v in Get-Versions) {
        $assets = Join-Path $AM_ROOT "$v\assets"
        if (-not $state.ContainsKey($v)) { $state[$v] = @{} }
        $vs = $state[$v]
        foreach ($f in Get-SettingsFiles $assets) {
            $path = Join-Path $assets $f
            $cur = Sha $path
            if ($vs.ContainsKey($f) -and $vs[$f]["patched"] -eq $cur) { continue }  # 이미 적용됨
            $bak = Join-Path $BACKUP "$v\$f"
            if (-not (Test-Path -LiteralPath $bak)) {
                if ($HANGUL.IsMatch((ReadText $path))) { continue }  # 원본 없이 이미 한글인 파일은 원본으로 저장하지 않는다
                New-Item -ItemType Directory -Force -Path (Split-Path $bak) | Out-Null
                Copy-Item -LiteralPath $path -Destination $bak -Force
            }
            $script:n = 0
            $out = $STR_RE.Replace((ReadText $bak), [Text.RegularExpressions.MatchEvaluator] {
                param($m)
                $t = $ko[$m.Groups[2].Value]
                if (-not $t -or $t -ceq $m.Groups[2].Value) { return $m.Value }
                $script:n++
                return $m.Groups[1].Value + ':"' + $t + '"'
            })
            if ($script:n -eq 0) { continue }
            WriteText $path $out
            $vs[$f] = @{ original = (Sha $bak); patched = (Sha $path); count = $script:n }
            $script:total += $script:n
        }
    }
    New-Item -ItemType Directory -Force -Path $HOME_DIR | Out-Null
    WriteText $STATE_PATH ($JSON.Serialize($state))
    $all = 0; foreach ($v in $state.Values) { foreach ($x in $v.Values) { $all += $x["count"] } }
    $latest = @(Get-Versions)[-1]
    Say "Aside 설정 화면을 한글로 바꾸는 중이에요..."
    Say "- 완료! 이번에 $($script:total)곳을 한글로 바꿨어요. (전체 ${all}곳)"
    Say "- 최신 버전: $(if ($latest) { $latest } else { '찾지 못함 (Aside 설치·로그인 후 설정 화면을 한 번 열어 주세요)' })"
    Say "- 영어 원본은 따로 보관해 뒀어요. 2_영어로_되돌리기.cmd 로 언제든 돌아갈 수 있어요."
    Say ""
    Say "설정 화면이 열려 있으면 F5를 눌러 새로고침해 주세요."
}

function Invoke-Revert {
    $state = LoadJson $STATE_PATH
    $restored = 0; $bad = @()
    foreach ($v in @($state.Keys)) {
        $assets = Join-Path $AM_ROOT "$v\assets"
        foreach ($f in @($state[$v].Keys)) {
            $bak = Join-Path $BACKUP "$v\$f"
            $path = Join-Path $assets $f
            if (-not ((Test-Path -LiteralPath $bak) -and (Test-Path -LiteralPath $assets))) { continue }
            Copy-Item -LiteralPath $bak -Destination $path -Force
            $restored++
            if ((Sha $path) -ne $state[$v][$f]["original"]) { $bad += "$v\$f" }
        }
    }
    New-Item -ItemType Directory -Force -Path $HOME_DIR | Out-Null
    WriteText $STATE_PATH "{}"
    Say "처음 상태(영어 원본)로 되돌리는 중이에요..."
    Say "- 파일 ${restored}개를 원본으로 되돌렸어요."
    Say $(if ($bad.Count -eq 0) { "- 원본과 똑같은 걸 확인했어요." } else { "- 주의: 원본과 다른 파일 $($bad.Count)개: $($bad -join ', ')" })
    Say ""
    Say "설정 화면을 새로고침(F5)하면 영어로 돌아가요."
}

function Show-Status {
    $state = LoadJson $STATE_PATH
    $latest = @(Get-Versions)[-1]
    $on = $latest -and $state.ContainsKey($latest) -and $state[$latest].Count -gt 0
    $task = Get-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue
    Say "지금 상태: $(if ($on) { '한글' } else { '영어' })"
    Say "영어 원본 보관: $(if (Test-Path -LiteralPath $BACKUP) { '정상' } else { '없음' })"
    Say "업데이트 뒤 자동으로 다시 한글로: $(if ($task) { '켜짐' } else { '꺼짐' })"
    Say "Aside 설정 화면 버전: $(if ($latest) { $latest } else { '찾지 못함' })"
}

function Invoke-Install {
    New-Item -ItemType Directory -Force -Path $HOME_DIR | Out-Null
    foreach ($f in "patch.ps1", "ko.json") {
        $src = Join-Path $HERE $f; $dst = Join-Path $HOME_DIR $f
        if ($src -ne $dst) { Copy-Item -LiteralPath $src -Destination $dst -Force }
    }
    $seed = Join-Path $HERE "backup_seed"  # 이미 한글로 바뀐 PC용 영어 원본 (배포판에는 없음)
    if (Test-Path -LiteralPath $seed) { Copy-Item -Path "$seed\*" -Destination $BACKUP -Recurse -Force -ErrorAction SilentlyContinue }

    # conhost --headless 로 돌려서 10분마다 창이 깜빡이지 않게 한다
    $ps = Join-Path $PSHOME "powershell.exe"
    $arg = "--headless `"$ps`" -NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $HOME_DIR 'patch.ps1')`" apply -quiet"
    $ok = $true
    try {
        $action = New-ScheduledTaskAction -Execute "conhost.exe" -Argument $arg
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 10)
        $logon = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
        Register-ScheduledTask -TaskName $TASK_NAME -Action $action -Trigger $trigger, $logon -Settings $settings -Force | Out-Null
    } catch { $ok = $false }

    $script:HERE = $HOME_DIR
    Invoke-Apply
    Say $(if ($ok) { "- 업데이트돼도 10분 안에 알아서 다시 한글로 바꿔요." } else { "- (자동 재적용 등록 실패: 업데이트 후엔 1번을 다시 눌러 주세요)" })
}

function Invoke-Uninstall {
    Unregister-ScheduledTask -TaskName $TASK_NAME -Confirm:$false -ErrorAction SilentlyContinue
    Invoke-Revert
    Say "- 자동으로 다시 한글로 바뀌는 기능도 껐어요."
}

try {
    switch ($cmd) {
        "install"   { Invoke-Install }
        "uninstall" { Invoke-Uninstall }
        "apply"     { Invoke-Apply }
        "revert"    { Invoke-Revert }
        default     { Show-Status }
    }
} catch {
    if (-not $quiet) { throw }
    New-Item -ItemType Directory -Force -Path $HOME_DIR | Out-Null
    Add-Content -LiteralPath (Join-Path $HOME_DIR "error.log") -Value "$(Get-Date -Format s) $_`n$($_.ScriptStackTrace)" -Encoding UTF8
}
