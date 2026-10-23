# Aside 한글패치 (Windows · Mac)

AI 브라우저 [Aside](https://aside.com)의 **설정 화면**을 한글로 바꾸는 비공식 패치입니다.
메뉴·설명·버튼·안내 문구 1,200여 곳을 한글로 바꿉니다.

## 받기

- **[⬇ Windows용 다운로드](https://github.com/echidna08/aside-korean/releases/latest/download/Aside_KoreanPatch_Windows.zip)**
- **[⬇ Mac용 다운로드](https://github.com/echidna08/aside-korean/releases/latest/download/Aside_KoreanPatch_Mac.zip)**

## Windows 사용법

1. 압축 풀기
2. `1_한글로_바꾸기.cmd` 더블클릭
   - 파란색 "Windows의 PC 보호" 창 → **[추가 정보] → [실행]**
   - "이 앱이 디바이스를 변경하도록 허용하시겠어요?" 창 → **예**
     (Aside 1.0.1022부터 설정 파일이 `Program Files` 안에 있어 관리자 권한이 필요합니다)
3. Aside 설정 화면에서 **F5**(새로고침)

## Mac 사용법

1. 압축 풀기
2. `1_한글로_바꾸기.command` 더블클릭
3. Aside 설정 화면에서 **Cmd+R**(새로고침)

**"열지 않음" 창이 뜨는 경우:** 서명 안 된 파일이라 macOS가 막는 것입니다. **'휴지통으로 이동'이 아니라 '완료'**를 누른 뒤 아래 중 하나를 진행합니다.

- **방법 1:** 시스템 설정 → 개인정보 보호 및 보안 → 맨 아래 **'그래도 열기'** (파일마다 한 번씩)
- **방법 2 (한 번에):** 터미널에 `xattr -cr ` 입력(끝에 한 칸 띄우기) → 압축 푼 폴더를 터미널 창에 끌어다 놓기 → 엔터

## 파일

| Windows | Mac | 기능 |
|---|---|---|
| `1_한글로_바꾸기.cmd` | `1_한글로_바꾸기.command` | 한글 적용 + 업데이트 뒤 자동 재적용 켜기 |
| `2_영어로_되돌리기.cmd` | `2_영어로_되돌리기.command` | 영어 원본으로 복원(원본과 같은지 검사) + 자동 재적용 끄기 |
| `3_상태_보기.cmd` | `3_상태_보기.command` | 한글/영어 상태, 패치 버전, 새 버전 여부 확인 |

별도 설치는 필요 없습니다. Windows는 PowerShell, Mac은 기본 내장 JavaScript(JXA)로 동작합니다.

## 업데이트 대응

- **Aside 업데이트:** 업데이트 후 10분 안에 자동으로 다시 한글로 바꿉니다.
  (Windows: 작업 스케줄러 `AsideKoreanPatch` / Mac: LaunchAgent `com.asidekoreanpatch`, `2_영어로_되돌리기` 실행 시 삭제)
- **패치 새 버전 알림 (v1.3.0부터):** 하루 한 번 새 버전을 확인하고, 새 버전이 나오면 Windows·Mac 알림을 한 번 띄웁니다.
  패치를 자동으로 바꾸지는 않습니다. 새 버전을 받은 뒤 `1_한글로_바꾸기`를 다시 실행하면 됩니다.
- **Aside가 구조를 크게 바꾸는 경우:** 패치 새 버전이 필요합니다. 위 알림 또는 이 페이지에서 확인할 수 있습니다.

## 참고

- Aside 공식 기능이 아닌 개인 제작 패치입니다. 사용 여부는 본인 판단에 맡깁니다.
- 설정 화면만 바꿉니다. 대화창·에이전트·브라우저 본체는 건드리지 않습니다.
- 영어 원본 보관 위치: Windows `%LOCALAPPDATA%\AsideKoreanPatch\backup`, Mac `~/Library/Application Support/AsideKoreanPatch/backup`
- 숫자·날짜가 섞인 문장 등 일부는 영어로 남을 수 있습니다.
- 문제가 있으면 `3_상태_보기` 결과와 함께 이슈로 알려 주세요.

## 동작 방식

Aside 설정 화면은 `AsideAgentManager/assets/` 안의 JS 파일입니다.
패치 스크립트(`files/patch.ps1`, `mac/files/patch.js`)가 설정 화면에서만 쓰는 파일을 골라,
화면에 보이는 `title:"..."`, `label:"..."` 같은 문자열만 `ko.json` 사전대로 바꿉니다. 코드의 다른 부분은 건드리지 않습니다.
