# Aside 한글패치 (Windows)

AI 브라우저 [Aside](https://aside.com)의 **설정 화면**을 한글로 바꿔 주는 비공식 패치예요.
메뉴·설명·버튼·안내 문구 1,200여 곳을 한글로 바꿔요.

## 받기

**[⬇ Aside_KoreanPatch_Windows.zip 다운로드](https://github.com/echidna08/aside-korean/releases/latest/download/Aside_KoreanPatch_Windows.zip)**

## 사용법

1. 압축을 풀어요.
2. `1_한글로_바꾸기.cmd`를 더블클릭해요.
   - 파란색 "Windows의 PC 보호" 창이 뜨면 **[추가 정보] → [실행]**을 눌러요.
3. Aside 설정 화면에서 **F5**(새로고침)를 눌러요.

| 파일 | 하는 일 |
|---|---|
| `1_한글로_바꾸기.cmd` | 한글 적용 + 업데이트 뒤 자동 재적용 켜기 |
| `2_영어로_되돌리기.cmd` | 영어 원본으로 완전히 되돌리기 (원본과 같은지 검사) + 자동 재적용 끄기 |
| `3_상태_보기.cmd` | 지금 한글인지 영어인지 확인 |

따로 설치할 건 없어요. Windows에 기본으로 있는 PowerShell로 돌아가요.

## 업데이트돼도 괜찮아요

Aside는 업데이트가 자주 돼요. 이 패치는 Windows 작업 스케줄러에 `AsideKoreanPatch` 작업을 등록해서
업데이트된 뒤 10분 안에 알아서 다시 한글로 바꿔요. `2_영어로_되돌리기.cmd`를 누르면 이 작업도 지워져요.

## 알아둘 것

- Aside 공식 기능이 아니라 개인이 만든 패치예요. 사용은 본인 판단으로 해 주세요.
- 설정 화면만 바꿔요. 대화창·에이전트·브라우저 본체는 건드리지 않아요.
- 영어 원본은 `%LOCALAPPDATA%\AsideKoreanPatch\backup`에 보관돼요.
- 숫자·날짜가 끼어 있는 문장 등 일부는 아직 영어로 남을 수 있어요.

## 어떻게 동작하나요

Aside 설정 화면은 `%LOCALAPPDATA%\Aside\User Data\AsideAgentManager\<버전>\assets\` 안의 JS 파일이에요.
`files/patch.ps1`이 설정 화면에서만 쓰는 파일을 골라, 화면에 보이는 `title:"..."`, `label:"..."` 같은 문자열만
`files/ko.json` 사전대로 바꿔요. 코드의 다른 부분은 건드리지 않아요.
