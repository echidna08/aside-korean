# Aside 설정 화면 한글패치 (Windows PowerShell 5.1 이상, 설치 필요 없음)
#
#   patch.ps1 install     고정 위치에 복사 + 10분마다 자동 재적용 등록 + 적용 (관리자 권한 필요)
#   patch.ps1 uninstall   자동 재적용 끄기 + 영어 원본으로 되돌리기 (관리자 권한 필요)
#   patch.ps1 apply       찾은 모든 설정 화면 묶음에 한글 적용 (이미 적용된 건 건너뜀)
#   patch.ps1 revert      영어 원본으로 되돌리기 + 원본과 같은지 검사
#   patch.ps1 status      지금 상태 보기
#   -quiet                출력 없이 (자동 재적용용, 오류는 error.log 에)
#
# 설정 화면 청크(AsideAgentManager\assets\*.js)의 key:"English" 문자열만 ko.json 대로 바꾼다.
# AsideAgentManager 는 두 군데에 있을 수 있다.
#   - %LOCALAPPDATA%\Aside\User Data\AsideAgentManager\<버전>\   (자동 업데이트로 받은 것, 묶음 이름 = <버전>)
#   - C:\Program Files\Aside\Application\<앱버전>\AsideAgentManager\ (Aside 1.0.1022 부터 기본 탑재, 묶음 이름 = app-<앱버전>)
# 영어 원본은 %LOCALAPPDATA%\AsideKoreanPatch\backup\<묶음 이름>\ 에 보관한다.
param([string]$cmd = "status", [switch]$quiet)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [Text.Encoding]::UTF8
Add-Type -AssemblyName System.Web.Extensions

$HERE = $PSScriptRoot
$AM_ROOT = if ($env:AKP_ROOT) { $env:AKP_ROOT } else { Join-Path $env:LOCALAPPDATA "Aside\User Data\AsideAgentManager" }
$APP_ROOTS = if ($env:AKP_APP_ROOT) { @($env:AKP_APP_ROOT) } else {
    @((Join-Path $env:ProgramFiles "Aside\Application"), (Join-Path ${env:ProgramFiles(x86)} "Aside\Application"),
      (Join-Path $env:LOCALAPPDATA "Aside\Application"))
}
$HOME_DIR = if ($env:AKP_HOME) { $env:AKP_HOME } else { Join-Path $env:LOCALAPPDATA "AsideKoreanPatch" }
$BACKUP = Join-Path $HOME_DIR "backup"
$STATE_PATH = Join-Path $HOME_DIR "state.json"
$TASK_NAME = "AsideKoreanPatch"
$PATCH_VERSION = "1.3.0"
$REPO = "echidna08/aside-korean"
$RELEASE_URL = "https://github.com/$REPO/releases/latest"
$UPDATE_PATH = Join-Path $HOME_DIR "update.json"
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
function SortKey($s) { try { [version]$s } catch { [version]"0.0" } }

function LoadJson($p) {
    if (Test-Path -LiteralPath $p) { try { return $JSON.DeserializeObject((ReadText $p)) } catch {} }
    return @{}
}

function Test-Admin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ── 새 버전 알림 (알림만 한다. 패치 교체는 사용자가 직접 1번을 눌러서) ──
function Get-LatestTag {
    if ($env:AKP_FAKE_LATEST) { return $env:AKP_FAKE_LATEST }
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $r = Invoke-RestMethod "https://api.github.com/repos/$REPO/releases/latest" -TimeoutSec 10 -Headers @{ "User-Agent" = "AsideKoreanPatch" }
        return [string]$r.tag_name
    } catch { return $null }
}

function Test-Newer($tag) {
    if (-not $tag) { return $false }
    try { return [version]($tag.TrimStart("v")) -gt [version]$PATCH_VERSION } catch { return $false }
}

# 하루에 한 번만 깃허브에 물어본다
function Get-UpdateInfo([switch]$force) {
    $u = LoadJson $UPDATE_PATH
    $today = (Get-Date).ToString("yyyy-MM-dd")
    if ($force -or $u["checked"] -ne $today) {
        $tag = Get-LatestTag
        if ($tag) {
            $u["latest"] = $tag; $u["checked"] = $today
            New-Item -ItemType Directory -Force -Path $HOME_DIR | Out-Null
            WriteText $UPDATE_PATH ($JSON.Serialize($u))
        }
    }
    $u
}

function Show-Toast($title, $body) {
    [void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
    [void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $xml.LoadXml("<toast activationType=`"protocol`" launch=`"$RELEASE_URL`"><visual><binding template=`"ToastGeneric`"><text>$title</text><text>$body</text></binding></visual><actions><action activationType=`"protocol`" content=`"받으러 가기`" arguments=`"$RELEASE_URL`"/></actions></toast>")
    $appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show([Windows.UI.Notifications.ToastNotification]::new($xml))
}

# 새 버전이 있으면 그 버전당 한 번만 알림을 띄운다
function Send-UpdateNotice {
    $u = Get-UpdateInfo
    $tag = $u["latest"]
    if (-not (Test-Newer $tag) -or $u["notified"] -eq $tag) { return }
    try { Show-Toast "Aside 한글패치 $tag 나왔어요" "Aside 업데이트로 영어로 보이면 새 버전을 받아 1_한글로_바꾸기.cmd 를 다시 실행해 주세요." } catch { return }
    $u["notified"] = $tag
    WriteText $UPDATE_PATH ($JSON.Serialize($u))
}

# 설정 화면 묶음 목록: 이름 → assets 폴더 (오래된 것부터)
function Get-Bundles {
    $list = @()
    if (Test-Path -LiteralPath $AM_ROOT) {
        foreach ($d in Get-ChildItem -LiteralPath $AM_ROOT -Directory) {
            if (Test-Path -LiteralPath (Join-Path $d.FullName "manifest.json")) {
                $list += [pscustomobject]@{ Id = $d.Name; Assets = Join-Path $d.FullName "assets"; Key = SortKey $d.Name; App = $false }
            }
        }
    }
    foreach ($root in $APP_ROOTS) {
        if (-not ($root -and (Test-Path -LiteralPath $root))) { continue }
        foreach ($d in Get-ChildItem -LiteralPath $root -Directory) {
            $am = Join-Path $d.FullName "AsideAgentManager"
            if (Test-Path -LiteralPath (Join-Path $am "manifest.json")) {
                $list += [pscustomobject]@{ Id = "app-$($d.Name)"; Assets = Join-Path $am "assets"; Key = SortKey $d.Name; App = $true }
            }
        }
    }
    @($list | Sort-Object App, Key)
}

function Find-Assets($id) {
    $b = @(Get-Bundles) | Where-Object { $_.Id -eq $id } | Select-Object -First 1
    if ($b) { $b.Assets } else { $null }
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
    $denied = @()
    $bundles = @(Get-Bundles)
    foreach ($b in $bundles) {
        $v = $b.Id; $assets = $b.Assets
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
            try { WriteText $path $out } catch { if ($denied -notcontains $v) { $denied += $v }; continue }  # Program Files 는 관리자만 쓸 수 있다
            $vs[$f] = @{ original = (Sha $bak); patched = (Sha $path); count = $script:n }
            $script:total += $script:n
        }
    }
    New-Item -ItemType Directory -Force -Path $HOME_DIR | Out-Null
    WriteText $STATE_PATH ($JSON.Serialize($state))
    $all = 0; foreach ($v in $state.Values) { foreach ($x in $v.Values) { $all += $x["count"] } }
    Say "Aside 설정 화면을 한글로 바꾸는 중이에요..."
    Say "- 완료! 이번에 $($script:total)곳을 한글로 바꿨어요. (전체 ${all}곳)"
    if ($bundles.Count -eq 0) { Say "- Aside 설정 파일을 찾지 못했어요. Aside 설치·로그인 후 설정 화면을 한 번 열어 주세요." }
    else { Say "- 찾은 설정 화면: $(($bundles | ForEach-Object Id) -join ', ')" }
    if ($denied.Count) { Say "- 권한이 없어 못 바꾼 곳: $($denied -join ', ') (1번을 다시 눌러 '예'로 허용해 주세요)" }
    Say "- 영어 원본은 따로 보관해 뒀어요. 2_영어로_되돌리기.cmd 로 언제든 돌아갈 수 있어요."
    Say ""
    Say "Aside 설정 화면이 열려 있으면 F5를 눌러 새로고침해 주세요."
    if ($quiet) { Send-UpdateNotice }  # 자동 재적용 때만
}

function Invoke-Revert {
    $state = LoadJson $STATE_PATH
    $restored = 0; $bad = @()
    foreach ($v in @($state.Keys)) {
        $assets = Find-Assets $v
        if (-not $assets) { continue }
        foreach ($f in @($state[$v].Keys)) {
            $bak = Join-Path $BACKUP "$v\$f"
            $path = Join-Path $assets $f
            if (-not (Test-Path -LiteralPath $bak)) { continue }
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
    $bundles = @(Get-Bundles)
    $task = Get-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue
    $on = @($bundles | Where-Object { $state.ContainsKey($_.Id) -and $state[$_.Id].Count -gt 0 })
    Say "지금 상태: $(if ($bundles.Count -and $on.Count -eq $bundles.Count) { '한글' } elseif ($on.Count) { '일부만 한글' } else { '영어' })"
    Say "영어 원본 보관: $(if (Test-Path -LiteralPath $BACKUP) { '정상' } else { '없음' })"
    Say "업데이트 뒤 자동으로 다시 한글로: $(if ($task) { '켜짐' } else { '꺼짐' })"
    foreach ($b in $bundles) { Say "  $($b.Id): $(if ($on -contains $b) { '한글' } else { '영어' })" }
    if (-not $bundles.Count) { Say "Aside 설정 화면: 찾지 못함" }
    $installed = Join-Path $HOME_DIR "patch.ps1"
    $iv = if (Test-Path -LiteralPath $installed) { ([regex]::Match((ReadText $installed), '\$PATCH_VERSION = "([^"]+)"')).Groups[1].Value } else { "" }
    Say "설치된 패치 버전: $(if ($iv) { $iv } else { '1.2.0 이하' })"
    $latest = (Get-UpdateInfo -force)["latest"]
    if (-not $latest) { Say "최신 버전: 확인 못 함 (인터넷 연결 확인)" }
    elseif ([version]$latest.TrimStart("v") -gt [version]$(if ($iv) { $iv } else { "1.2.0" })) { Say "새 버전 $latest 나왔어요 → $RELEASE_URL 에서 받아서 1번을 다시 실행해 주세요." }
    else { Say "최신 버전이에요. ($latest)" }
}

function Invoke-Install {
    if (-not (Test-Admin)) {
        Say "관리자 권한이 필요해요. (Aside 설정 파일이 Program Files 안에 있어요)"
        Say "1_한글로_바꾸기.cmd 를 다시 실행해서 '예'를 눌러 주세요."
        return
    }
    New-Item -ItemType Directory -Force -Path $HOME_DIR | Out-Null
    foreach ($f in "patch.ps1", "ko.json") {
        $src = Join-Path $HERE $f; $dst = Join-Path $HOME_DIR $f
        if ($src -ne $dst) { Copy-Item -LiteralPath $src -Destination $dst -Force }
    }
    $seed = Join-Path $HERE "backup_seed"  # 이미 한글로 바뀐 PC용 영어 원본 (배포판에는 없음)
    if (Test-Path -LiteralPath $seed) {
        New-Item -ItemType Directory -Force -Path $BACKUP | Out-Null
        foreach ($d in Get-ChildItem -LiteralPath $seed -Directory) {
            Copy-Item -LiteralPath $d.FullName -Destination $BACKUP -Recurse -Force
        }
    }

    # 관리자 권한으로 돌아야 Program Files 를 고칠 수 있다. conhost --headless 로 창이 깜빡이지 않게 한다
    $ps = Join-Path $PSHOME "powershell.exe"
    $arg = "--headless `"$ps`" -NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $HOME_DIR 'patch.ps1')`" apply -quiet"
    $ok = $true
    try {
        $user = "$env:USERDOMAIN\$env:USERNAME"
        $action = New-ScheduledTaskAction -Execute "conhost.exe" -Argument $arg
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 10)
        $logon = New-ScheduledTaskTrigger -AtLogOn -User $user
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
        $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
        Register-ScheduledTask -TaskName $TASK_NAME -Action $action -Trigger $trigger, $logon -Settings $settings -Principal $principal -Force | Out-Null
    } catch { $ok = $false }

    $script:HERE = $HOME_DIR
    Invoke-Apply
    Say $(if ($ok) { "- 업데이트돼도 10분 안에 알아서 다시 한글로 바꿔요." } else { "- (자동 재적용 등록 실패: 업데이트 후엔 1번을 다시 눌러 주세요)" })
}

function Invoke-Uninstall {
    if (-not (Test-Admin)) {
        Say "관리자 권한이 필요해요. 2_영어로_되돌리기.cmd 를 다시 실행해서 '예'를 눌러 주세요."
        return
    }
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
