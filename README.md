# Aside 한글패치 (Windows · Mac)

AI 브라우저 [Aside](https://aside.com)의 **설정 화면**을 한글로 바꿔 주는 비공식 패치예요.
메뉴·설명·버튼·안내 문구 1,200여 곳을 한글로 바꿔요.

## 받기

- **[⬇ Windows용 다운로드](https://github.com/echidna08/aside-korean/releases/latest/download/Aside_KoreanPatch_Windows.zip)**
- **[⬇ Mac용 다운로드](https://github.com/echidna08/aside-korean/releases/latest/download/Aside_KoreanPatch_Mac.zip)**

## Windows 사용법

1. 압축을 풀어요.
2. `1_한글로_바꾸기.cmd`를 더블클릭해요.
   - 파란색 "Windows의 PC 보호" 창이 뜨면 **[추가 정보] → [실행]**을 눌러요.
   - "이 앱이 디바이스를 변경하도록 허용하시겠어요?" 창이 뜨면 **예**를 눌러요. (Aside 1.0.1022부터 설정 파일이 `Program Files` 안에 있어서 관리자 권한이 필요해요)
3. Aside 설정 화면에서 **F5**(새로고침)를 눌러요.

## Mac 사용법

1. 압축을 풀어요.
2. `1_한글로_바꾸기.command`를 더블클릭해요.
3. Aside 설정 화면에서 **Cmd+R**(새로고침)을 눌러요.

**"열지 않음" 창이 뜨면** 서명 안 된 파일이라 macOS가 막는 거예요. **'휴지통으로 이동' 말고 '완료'**를 누르고 아래 중 하나를 하세요.

- **방법 1:** 시스템 설정 → 개인정보 보호 및 보안 → 맨 아래 **'그래도 열기'** (파일마다 한 번씩)
- **방법 2 (한 번에):** 터미널에 `xattr -cr ` 입력(끝에 한 칸 띄우기) → 압축 푼 폴더를 터미널 창에 끌어다 놓기 → 엔터

## 파일

| Windows | Mac | 하는 일 |
|---|---|---|
| `1_한글로_바꾸기.cmd` | `1_한글로_바꾸기.command` | 한글 적용 + 업데이트 뒤 자동 재적용 켜기 |
| `2_영어로_되돌리기.cmd` | `2_영어로_되돌리기.command` | 영어 원본으로 완전히 되돌리기 (원본과 같은지 검사) + 자동 재적용 끄기 |
| `3_상태_보기.cmd` | `3_상태_보기.command` | 지금 한글인지 영어인지 확인 |

따로 설치할 건 없어요. Windows는 PowerShell, Mac은 기본 내장 JavaScript(JXA)로 돌아가요.

## 업데이트돼도 괜찮아요

Aside는 업데이트가 자주 돼요. 이 패치는 업데이트된 뒤 10분 안에 알아서 다시 한글로 바꿔요.
(Windows: 작업 스케줄러 `AsideKoreanPatch` / Mac: LaunchAgent `com.asidekoreanpatch`)
`2_영어로_되돌리기`를 누르면 이것도 지워져요.

## 알아둘 것

- Aside 공식 기능이 아니라 개인이 만든 패치예요. 사용은 본인 판단으로 해 주세요.
- 설정 화면만 바꿔요. 대화창·에이전트·브라우저 본체는 건드리지 않아요.
- 영어 원본 보관 위치: Windows `%LOCALAPPDATA%\AsideKoreanPatch\backup`, Mac `~/Library/Application Support/AsideKoreanPatch/backup`
- 숫자·날짜가 끼어 있는 문장 등 일부는 아직 영어로 남을 수 있어요.
- 안 되면 `3_상태_보기` 결과와 함께 이슈로 알려 주세요.

## 어떻게 동작하나요

Aside 설정 화면은 `AsideAgentManager/<버전>/assets/` 안의 JS 파일이에요.
패치 스크립트(`files/patch.ps1`, `mac/files/patch.js`)가 설정 화면에서만 쓰는 파일을 골라,
화면에 보이는 `title:"..."`, `label:"..."` 같은 문자열만 `ko.json` 사전대로 바꿔요. 코드의 다른 부분은 건드리지 않아요.
