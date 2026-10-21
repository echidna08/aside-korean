// Aside 설정 화면 한글패치 (macOS, JavaScript for Automation — 설치 필요 없음)
//
//   osascript -l JavaScript patch.js install     고정 위치에 복사 + 10분마다 자동 재적용 등록 + 적용
//   osascript -l JavaScript patch.js uninstall   자동 재적용 끄기 + 영어 원본으로 되돌리기
//   osascript -l JavaScript patch.js apply       설치된 모든 버전에 한글 적용 (이미 적용된 건 건너뜀)
//   osascript -l JavaScript patch.js revert      영어 원본으로 되돌리기 + 원본과 같은지 검사
//   osascript -l JavaScript patch.js status      지금 상태 보기
//   --quiet                                      출력 없이 (자동 재적용용, 오류는 error.log 에)
//
// 설정 화면 청크(AsideAgentManager/<버전>/assets/*.js)의 key:"English" 문자열만 ko.json 대로 바꾼다.
// 영어 원본은 ~/Library/Application Support/AsideKoreanPatch/backup/<버전>/ 에 보관한다.
// Windows판(patch.ps1)과 같은 규칙이다. Node 로도 돌아가게 해서 PC에서 테스트한다.

const IS_JXA = typeof ObjC !== "undefined";
const LABEL = "com.asidekoreanpatch";

// ── 파일 입출력 (JXA / Node) ──────────────────────────────────────────
const io = IS_JXA ? (() => {
  ObjC.import("Foundation");
  const fm = $.NSFileManager.defaultManager;
  const app = Application.currentApplication();
  app.includeStandardAdditions = true;
  return {
    env: (k) => { const v = $.NSProcessInfo.processInfo.environment.objectForKey(k); return v.isNil() ? "" : v.js; },
    read: (p) => $.NSString.stringWithContentsOfFileEncodingError(p, $.NSUTF8StringEncoding, null).js,
    write: (p, s) => $(s).writeToFileAtomicallyEncodingError(p, true, $.NSUTF8StringEncoding, null),
    exists: (p) => fm.fileExistsAtPath(p),
    isDir: (p) => { const d = Ref(); return fm.fileExistsAtPathIsDirectory(p, d) && d[0]; },
    list: (p) => ObjC.unwrap(fm.contentsOfDirectoryAtPathError(p, null)).map((x) => ObjC.unwrap(x)),
    mkdir: (p) => fm.createDirectoryAtPathWithIntermediateDirectoriesAttributesError(p, true, $(), null),
    copy: (a, b) => { if (fm.fileExistsAtPath(b)) fm.removeItemAtPathError(b, null); fm.copyItemAtPathToPathError(a, b, null); },
    sh: (cmd) => { try { return { ok: true, out: app.doShellScript(cmd) }; } catch (e) { return { ok: false, out: String(e) }; } },
    log: (s) => console.log(s),
    scriptDir: () => {
      let p = ObjC.unwrap($.NSProcessInfo.processInfo.arguments).map((x) => ObjC.unwrap(x)).find((a) => a.endsWith("patch.js"));
      if (!p.startsWith("/")) p = fm.currentDirectoryPath.js + "/" + p;
      return $(p).stringByStandardizingPath.stringByDeletingLastPathComponent.js;
    },
  };
})() : (() => {
  const fs = require("fs"), path = require("path"), cp = require("child_process");
  return {
    env: (k) => process.env[k] || "",
    read: (p) => fs.readFileSync(p, "utf8"),
    write: (p, s) => fs.writeFileSync(p, s, "utf8"),
    exists: (p) => fs.existsSync(p),
    isDir: (p) => fs.existsSync(p) && fs.statSync(p).isDirectory(),
    list: (p) => fs.readdirSync(p),
    mkdir: (p) => fs.mkdirSync(p, { recursive: true }),
    copy: (a, b) => fs.copyFileSync(a, b),
    sh: (cmd) => { try { return { ok: true, out: cp.execSync(cmd, { stdio: "pipe" }).toString() }; } catch (e) { return { ok: false, out: String(e) }; } },
    log: (s) => console.log(s),
    scriptDir: () => __dirname,
  };
})();

const join = (...a) => a.join("/").replace(/\/+/g, "/");
const dirname = (p) => p.replace(/\/[^/]*$/, "");
const q = (s) => "'" + s.replace(/'/g, "'\\''") + "'";

// ── 경로 ────────────────────────────────────────────────────────────
const HOME = io.env("HOME");
const APP_SUPPORT = join(HOME, "Library/Application Support");
const HOME_DIR = io.env("AKP_HOME") || join(APP_SUPPORT, "AsideKoreanPatch");
const BACKUP = join(HOME_DIR, "backup");
const STATE_PATH = join(HOME_DIR, "state.json");
const PLIST = join(HOME, "Library/LaunchAgents", LABEL + ".plist");
let HERE = io.scriptDir();
let QUIET = false;

// Aside 폴더 위치는 버전마다 다를 수 있어서 Application Support 아래를 찾아본다
function findRoot() {
  if (io.env("AKP_ROOT")) return io.env("AKP_ROOT");
  const first = join(APP_SUPPORT, "Aside/AsideAgentManager");
  if (io.isDir(first)) return first;
  if (!io.isDir(APP_SUPPORT)) return "";
  for (const a of io.list(APP_SUPPORT).filter((n) => /aside/i.test(n))) {
    const d1 = join(APP_SUPPORT, a);
    if (!io.isDir(d1)) continue;
    if (io.isDir(join(d1, "AsideAgentManager"))) return join(d1, "AsideAgentManager");
    for (const b of io.list(d1)) {
      if (io.isDir(join(d1, b, "AsideAgentManager"))) return join(d1, b, "AsideAgentManager");
    }
  }
  return "";
}
const AM_ROOT = findRoot();

// ── 패치 규칙 (patch.ps1 과 같음) ───────────────────────────────────
const KEYS = 'children|title|description|label|placeholder|"aria-label"|tooltip|message|subtitle|heading|text|confirmLabel|cancelLabel|emptyMessage|helperText|hint|caption|badge|ctaLabel|buttonLabel|confirmText|alt';
// 오래된 macOS(JavaScriptCore)에 lookbehind 가 없어서 앞 글자를 그룹으로 잡는다
const STR_RE = new RegExp('(^|[^\\w$.])(' + KEYS + '):"((?:[^"\\\\]|\\\\.)*)"', "g");
const ROUTE_RE = /import\("\.\/([\w.-]+\.js)"\),__vite__mapDeps\(\[([\d,]*)\]\)\).{0,40}?=\w+\("([^"]+)"\)/g;
const HANGUL = /[가-힣]/;

function say(s) { if (!QUIET) io.log(s); }

function hash(s) {  // FNV-1a 32bit — 바뀌었는지 보는 용도
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 0x01000193) >>> 0; }
  return h.toString(16) + ":" + s.length;
}

function loadJson(p) {
  try { return io.exists(p) ? JSON.parse(io.read(p)) : {}; } catch (e) { return {}; }
}

function versions() {
  if (!AM_ROOT || !io.isDir(AM_ROOT)) return [];
  const key = (v) => v.split(".").map((x) => (/^\d+$/.test(x) ? +x : 0));
  return io.list(AM_ROOT)
    .filter((v) => io.exists(join(AM_ROOT, v, "manifest.json")))
    .sort((a, b) => { const x = key(a), y = key(b); for (let i = 0; i < Math.max(x.length, y.length); i++) { if ((x[i] || 0) !== (y[i] || 0)) return (x[i] || 0) - (y[i] || 0); } return 0; });
}

// 설정 라우트만 쓰는 청크 (설정 밖 라우트도 쓰는 공용 청크는 제외)
function settingsFiles(assets) {
  const main = io.list(assets).find((f) => f.startsWith("extension-main-") && f.endsWith(".js"));
  if (!main) return [];
  const s = io.read(join(assets, main));
  const m = s.match(/m\.f=(\[.*?\])\)/);
  if (!m) return [];
  const depNames = JSON.parse(m[1]).map((p) => p.split("/").pop());
  const inside = new Set(), outside = new Set();
  for (const r of s.matchAll(ROUTE_RE)) {
    const set = r[3].includes("settings") ? inside : outside;
    set.add(r[1]);
    for (const i of r[2].split(",")) if (i) set.add(depNames[+i]);
  }
  return [...inside].filter((f) => !outside.has(f) && io.exists(join(assets, f))).sort();
}

function translate(src, ko) {
  let n = 0;
  const out = src.replace(STR_RE, (all, pre, key, s) => {
    const t = ko.get(s);
    if (!t || t === s) return all;
    n++;
    return pre + key + ':"' + t + '"';
  });
  return [out, n];
}

// ── 명령 ────────────────────────────────────────────────────────────
function apply() {
  const ko = new Map(Object.entries(loadJson(join(HERE, "ko.json"))));
  const state = loadJson(STATE_PATH);
  let total = 0;
  for (const v of versions()) {
    const assets = join(AM_ROOT, v, "assets");
    const vs = (state[v] = state[v] || {});
    for (const f of settingsFiles(assets)) {
      const path = join(assets, f);
      const cur = io.read(path);
      if (vs[f] && vs[f].patched === hash(cur)) continue;  // 이미 적용됨
      const bak = join(BACKUP, v, f);
      if (!io.exists(bak)) {
        if (HANGUL.test(cur)) continue;  // 원본 없이 이미 한글인 파일은 원본으로 저장하지 않는다
        io.mkdir(dirname(bak));
        io.copy(path, bak);
      }
      const orig = io.read(bak);
      const [out, n] = translate(orig, ko);
      if (n === 0) continue;
      io.write(path, out);
      vs[f] = { original: hash(orig), patched: hash(out), count: n };
      total += n;
    }
  }
  io.mkdir(HOME_DIR);
  io.write(STATE_PATH, JSON.stringify(state));
  let all = 0;
  for (const v of Object.values(state)) for (const x of Object.values(v)) all += x.count;
  const vs = versions();
  say("Aside 설정 화면을 한글로 바꾸는 중이에요...");
  if (!AM_ROOT) say("- Aside 설정 파일을 찾지 못했어요. Aside 설치·로그인 후 설정 화면을 한 번 열고 다시 해 주세요.");
  say(`- 완료! 이번에 ${total}곳을 한글로 바꿨어요. (전체 ${all}곳)`);
  say(`- 최신 버전: ${vs.length ? vs[vs.length - 1] : "찾지 못함"}`);
  say("- 영어 원본은 따로 보관해 뒀어요. 2_영어로_되돌리기.command 로 언제든 돌아갈 수 있어요.");
  say("");
  say("설정 화면이 열려 있으면 Cmd+R 을 눌러 새로고침해 주세요.");
}

function revert() {
  const state = loadJson(STATE_PATH);
  let restored = 0; const bad = [];
  for (const v of Object.keys(state)) {
    const assets = join(AM_ROOT, v, "assets");
    for (const f of Object.keys(state[v])) {
      const bak = join(BACKUP, v, f);
      if (!(io.exists(bak) && io.isDir(assets))) continue;
      io.copy(bak, join(assets, f));
      restored++;
      if (hash(io.read(join(assets, f))) !== state[v][f].original) bad.push(`${v}/${f}`);
    }
  }
  io.mkdir(HOME_DIR);
  io.write(STATE_PATH, "{}");
  say("처음 상태(영어 원본)로 되돌리는 중이에요...");
  say(`- 파일 ${restored}개를 원본으로 되돌렸어요.`);
  say(bad.length ? `- 주의: 원본과 다른 파일 ${bad.length}개: ${bad.join(", ")}` : "- 원본과 똑같은 걸 확인했어요.");
  say("");
  say("설정 화면을 새로고침(Cmd+R)하면 영어로 돌아가요.");
}

function agentLoaded() {
  return io.sh(`launchctl print gui/$(id -u)/${LABEL} >/dev/null 2>&1`).ok;
}

function status() {
  const state = loadJson(STATE_PATH);
  const vs = versions();
  const latest = vs[vs.length - 1];
  const on = latest && state[latest] && Object.keys(state[latest]).length > 0;
  say(`지금 상태: ${on ? "한글" : "영어"}`);
  say(`영어 원본 보관: ${io.isDir(BACKUP) ? "정상" : "없음"}`);
  say(`업데이트 뒤 자동으로 다시 한글로: ${agentLoaded() ? "켜짐" : "꺼짐"}`);
  say(`Aside 설정 화면 버전: ${latest || "찾지 못함"}`);
  say(`Aside 설정 폴더: ${AM_ROOT || "찾지 못함"}`);
}

function install() {
  io.mkdir(HOME_DIR);
  for (const f of ["patch.js", "ko.json"]) {
    if (join(HERE, f) !== join(HOME_DIR, f)) io.copy(join(HERE, f), join(HOME_DIR, f));
  }
  const plist = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/osascript</string>
    <string>-l</string>
    <string>JavaScript</string>
    <string>${join(HOME_DIR, "patch.js").replace(/&/g, "&amp;")}</string>
    <string>apply</string>
    <string>--quiet</string>
  </array>
  <key>StartInterval</key><integer>600</integer>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
`;
  io.mkdir(dirname(PLIST));
  io.write(PLIST, plist);
  io.sh(`launchctl bootout gui/$(id -u)/${LABEL} 2>/dev/null`);
  const r = io.sh(`launchctl bootstrap gui/$(id -u) ${q(PLIST)}`);
  HERE = HOME_DIR;
  apply();
  say(r.ok || agentLoaded() ? "- 업데이트돼도 10분 안에 알아서 다시 한글로 바꿔요."
    : "- (자동 재적용 등록 실패: 업데이트 후엔 1번을 다시 눌러 주세요)");
}

function uninstall() {
  io.sh(`launchctl bootout gui/$(id -u)/${LABEL} 2>/dev/null`);
  io.sh(`rm -f ${q(PLIST)}`);
  revert();
  say("- 자동으로 다시 한글로 바뀌는 기능도 껐어요.");
}

function main(argv) {
  QUIET = argv.includes("--quiet");
  const cmd = argv.find((a) => !a.startsWith("--")) || "status";
  try {
    ({ install, uninstall, apply, revert, status }[cmd] || status)();
  } catch (e) {
    if (!QUIET) throw e;
    io.mkdir(HOME_DIR);
    const log = join(HOME_DIR, "error.log");
    io.write(log, (io.exists(log) ? io.read(log) : "") + new Date().toISOString() + " " + e + "\n");
  }
}

// JXA 는 run(argv) 를 부르고, Node 에서는 바로 실행한다
function run(argv) { main(argv); }
if (!IS_JXA) main(process.argv.slice(2));
