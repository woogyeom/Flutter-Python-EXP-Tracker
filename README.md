# Mapleland EXP Tracker

**Mapleland EXP Tracker**는 Mapleland라는 온라인 게임에서 캐릭터의 경험치 상승을 지속적으로 측정하고 시각화해주는 Flutter-Python 기반 애플리케이션입니다.  
사용자가 사냥하면서 캐릭터의 레벨 및 경험치 수치를 손쉽게 추적할 수 있도록 설계되었습니다.

---

### 앱의 구조 및 동작 과정
**Mapleland EXP Tracker**는 **Flutter**로 개발된 클라이언트 앱과 **Python 기반 FastAPI** 서버로 구성되어 있습니다.  
각각의 역할과 동작 과정을 간략히 설명하면 다음과 같습니다:

- **Flutter 클라이언트:**  
  - 사용자 인터페이스(UI)를 제공하며 경험치와 레벨 데이터를 실시간으로 표시.  
  - ROI(Region of Interest) 설정을 통해 경험치 및 레벨 데이터가 표시될 영역을 선택.  
  - 타이머를 통해 수집된 데이터를 누적하고, 퍼센트를 계산하여 보여줌.

- **Python 서버:**  
  - 클라이언트에서 받은 ROI 좌표를 기반으로 화면을 캡처.  
  - Tesseract OCR을 사용하여 텍스트를 추출하고 유효한 경험치와 레벨 값을 파싱.  
  - FastAPI로 데이터를 클라이언트에 전달하여, 실시간 업데이트를 지원.

이처럼 클라이언트-서버 아키텍처를 통해, 각 구성 요소는 독립적으로 동작하면서도 서로 긴밀히 연결되어 실시간 경험치 추적 기능을 제공합니다.

## 사용된 라이브러리
**Flutter**:
- [window_manager](https://pub.dev/packages/window_manager): 창을 제어하고 전체 화면 및 창 이동을 지원.
- [google_fonts](https://pub.dev/packages/google_fonts): 다양한 글꼴 스타일로 텍스트 표시.
- [http](https://pub.dev/packages/http): 서버와의 데이터 통신을 처리.
- [url_launcher](https://pub.dev/packages/url_launcher): 외부 URL 열기 기능 제공.
- [intl](https://pub.dev/packages/intl): 숫자의 형식을 국제화된 방식으로 포맷.
- [audioplayers](https://pub.dev/packages/audioplayers): 오디오 파일을 재생할 수 있는 기능 제공.
- [synchronized](https://pub.dev/packages/synchronized): 한 번에 하나의 비동기 작업만 실행되도록 제어하는 기능 제공(로깅에 사용).
- [hotkey_manager](https://pub.dev/packages/hotkey_manager): 시스템 와이드 핫키 기능 제공.

**Python**:
- [FastAPI](https://fastapi.tiangolo.com/): 고성능 비동기 웹 프레임워크로, API 서버 및 OCR 데이터 제공.
- [pytesseract](https://pypi.org/project/pytesseract/): Tesseract OCR 엔진으로 이미지에서 텍스트 추출.
- [mss](https://pypi.org/project/mss/): 화면 캡처를 통해 ROI 영역 이미지를 빠르게 저장.
- [uvicorn](https://www.uvicorn.org/): ASGI 서버로 FastAPI를 실행.
- [contextlib](https://docs.python.org/3/library/contextlib.html): with 문 관련 컨텍스트 관리자를 쉽게 구현하고 활용할 수 있도록 돕는 유틸리티 제공(로깅에 사용).

---

## 사용 방법
1. 앱을 실행한 뒤, 영역 지정 버튼을 눌러 게임 화면에서 경험치와 레벨이 표시되는 영역을 예시에 맞게 지정합니다.
2. 영역 설정이 완료되면 타이머를 시작하여 실시간 데이터를 수집합니다.
3. 앱 화면에서 경험치 증가량과 퍼센트 상승치를 실시간으로 확인하며 사냥 효율을 분석합니다.
5. 설정 버튼을 눌러 설정 페이지로 이동하면, 타이머 시간을 지정할 수 있으며 평균 경험치 표시도 활성화할 수 있습니다.
6. CapsLock + `(backquote) 핫키를 이용해 앱이 백그라운드 상태일 때도 타이머를 일시정지/재개할 수 있습니다.

## 상단 메뉴 아이콘 설명

- <img width="28" alt="Github" src="https://github.com/user-attachments/assets/be86422e-8cb9-40de-9115-6dec36b2eb3f" />  **깃허브 페이지 열기:** 현재 깃허브 페이지를 열어 관련 정보를 확인할 수 있습니다.
- <img width="47" alt="메소 측정 토글" src="https://github.com/user-attachments/assets/106f2baa-4521-4cf7-87ef-6595367d6758" />  **메소 측정 모드 토글:** 메소 측정 모드를 활성화하거나 비활성화할 수 있습니다.
- <img width="28" alt="타이머 초기화" src="https://github.com/user-attachments/assets/849c99a6-4f08-4166-af27-9b64c1f351a7" />  **타이머 및 측정값 초기화:** 타이머와 현재까지 측정된 값을 초기 상태로 리셋합니다.
- <img width="28" alt="인식 영역 재설정" src="https://github.com/user-attachments/assets/d1f13ed3-f487-4da6-8ba9-405c802022e9" />  **인식 영역 재설정:** 경험치와 레벨이 표시되는 영역을 다시 지정할 수 있습니다.
- <img width="28" alt="설정 화면 이동" src="https://github.com/user-attachments/assets/713dad68-43c4-4f0a-9066-187df0a485e7" />  **설정 화면 이동:** 타이머 시간 설정 및 평균 경험치 표시 활성화 등의 추가 설정을 조정할 수 있습니다.
- <img width="28" alt="앱 종료" src="https://github.com/user-attachments/assets/fdd7fe75-befb-4132-9b76-90c5b8d2afa5" />  **앱 종료:** 앱을 안전하게 종료합니다.

## 사용 예시 영상

[![사용 예시 영상](https://img.youtube.com/vi/8o71FTWMrao/maxresdefault.jpg)](https://youtu.be/8o71FTWMrao)

위 이미지를 클릭하시면 앱의 사용 예시를 확인하실 수 있습니다.

## 주의 사항

>메이플랜드 측에 문제 여부를 확인하기 위해 문의를 넣었고, 첫 문의에서는 단순히 권장하지 않는다는 짧은 답변을 받았으며, 이후 직접 사용하는 영상을 첨부하고 **제 자신을 신고**까지 해보았으나, 여전히 "검토해보겠다"는 모호한 답변만을 받고 있는 상태입니다.
>
>본 앱은 **메이플 월드 클라이언트나 네트워크에 어떠한 접근도 하지 않으며, 자동화 매크로가 아니고, 게임 플레이에 영향을 주는 프로그램이 아니라고 판단**하여 배포를 시작하려 합니다. 개발자인 저 역시 **수 주 간 직접 저 자신을 신고해 가면서까지 본 앱을 사용해왔지만, 아무런 문제가 없었으며 앞으로도 계속 사용할 예정**입니다. 다만, 앱 사용에 대한 책임은 **개발자인 저를 포함 각 사용자에게 있음**을 유의해 주시기 바랍니다.

+ 본 앱은 Windows 환경에서만 테스트되었습니다.
+ 1초마다 화면을 캡처하고 OCR(광학 문자 인식)을 수행하므로 일정량의 메모리를 점유합니다.
+ 게임을 저해상도로 플레이할 경우 인식 정확도가 저하될 수 있습니다.
+ 설정된 영역의 UI가 가려지지 않도록 주의해 주세요.
+ 게임 내에서 맵 이동이나 월드 이동이 빈번할 경우, 일시적으로 오인식이 발생할 수 있습니다.
+ 본 앱은 C:\temp\MaplelandEXPTracker 경로에 임시 폴더를 생성하고, 디버그용 이미지 파일과 최근 3일 간의 로그 파일들을 저장합니다.

---

## 다운로드 링크
- 본 앱을 실행할 때 "알 수 없는 게시자" 경고가 표시될 수 있습니다. 이는 코드 서명을 추가하지 않았기 때문이며, 이를 해결하려면 유료 인증서가 필요하여 개인 개발자로서는 부담이 큽니다. 이에 따라, 신뢰성을 보장하기 위해 코드를 오픈 소스로 공개하였음을 안내드립니다.
- 아래 링크는 제 구글 드라이브에 업로드 된 파일로 연결되며, 대략적인 다운로드 횟수를 파악하기 위해 불가피하게 단축 주소를 사용했습니다.

![image](https://github.com/user-attachments/assets/cf5267b0-cd66-46e7-bb4a-0debf55fc2f8)

🔗 [앱 다운로드](https://l.linklyhq.com/l/23vxv)
🔗 [앱 다운로드 예비 링크](https://2ly.link/29bOU)

**현재 버전 1.7.1**

**기존 메이플스토리 월드 폰트를 사용해주세요.   
버전 1.6.0 이후로 타이머의 기본 조작 방식이 변경되었습니다.   
초기화 버튼은 상단 메뉴에 있습니다.**

---

## 자주 묻는 질문

### 앱을 실행시켜도 아무런 창이 뜨지 않아요!
최신 버전의 **MSVC 런타임 라이브러리**가 설치되지 않았을 가능성이 있습니다.  
아래 링크에서 최신 버전을 다운로드하여 설치한 후 다시 실행해주세요.

🔗 [MSVC 런타임 라이브러리 다운로드](https://learn.microsoft.com/ko-kr/cpp/windows/latest-supported-vc-redist?view=msvc-170)

### 타이머 종료 효과음이 마음에 들지 않아요!
앱이 설치된 폴더\data\flutter_assets\assets 경로에 timer_alarm.mp3 파일을 원하시는 효과음 파일로 교체하시면 됩니다.

---

## 개발자에게 문의

버그 제보 및 기타 문의는 아래 오픈 채팅 링크를 이용해주세요.  
🔗 [오픈 채팅방 바로가기](https://open.kakao.com/o/sm79OLeh)

### 버그 제보 시  
가능하면 **상황 설명과 함께 아래 로그 파일도 첨부**해 주세요.  
더 정확한 확인과 해결에 도움이 됩니다.  

**로그 파일 위치**  
`C:\temp\MaplelandEXPTracker\client_log`  
`C:\temp\MaplelandEXPTracker\server_log`  

감사합니다.

---

## 업데이트 내역

+ Ver 1.0.0: 정식 배포 시작
+ Ver 1.0.2: 모니터 배율 적용 시 발생하는 ROI 관련 버그 수정
+ Ver 1.1.0: 설정 저장 기능 추가, 평균 경험치 계산 옵션 추가
+ Ver 1.1.1: ROI 설정을 불러오는 과정에서 누락된 서버 통신 기능 수정
+ Ver 1.1.2: 경험치 숫자 표시 형식을 1,000,000 형태로 변경
+ Ver 1.1.3: 임시 폴더 경로 지정 추가 (한글 사용자명 환경에서도 정상 동작하도록 명시적 지정)
+ Ver 1.1.4: 임시 폴더 내에 서버 로그 저장 추가
+ Ver 1.1.5: 서버 준비 확인 시 타임아웃 시간 연장하여 안정성 개선, 타임아웃 시 오류 알림 표시
+ Ver 1.2.0: 타이머 시간 만료 정지 시 알람 소리 추가, 볼륨 설정 옵션 추가
+ Ver 1.3.0: 임시 폴더 내에 클라이언트 로그 저장 추가, 메소 측정/집계 기능 시범 추가, 로컬 서버 포트 1108로 변경, 최근 3일 로그만 저장하게 수정, 초기 볼륨이 항상 0.5로 설정되던 오류 수정, config.json 파일 내부에 새로 추가된 필드가 없을 시 서버와 연결이 실패하던 오류 수정, 경험치/메소 집계 로직을 1초 전 수치와 비교하는 방식에서 초기값과 비교하는 방식으로 수정
+ Ver 1.3.1: PyInstaller 빌드 시 stdout/stderr 재설정으로 uvicorn 로깅 오류 해결
+ Ver 1.3.2: JSON 파싱 오류 발생 시 빈 JSON 파일 재생성하게 수정, 타임아웃 시 로그를 남긴 후 앱을 종료하게 수정, 안전 상태 업데이트 기능 추가, 각 초기화 작업을 명확히 분리, 분산되어 있던 여러 setState 호출 및 비동기 작업들을 통합·분리
+ Ver 1.3.4: 서버 로그 기록 기능 보완, 로컬 서버 포트 5000로 재변경, 서버 초기화 구조 개선
+ Ver 1.3.5: 앱 실행 시 로그 기록. exit 호출 직전 로그 기록은 await처리
+ Ver 1.3.6: 업데이트 주기 설정 옵션 추가, 초기 경험치 및 메소 데이터가 인식되기 전까지 --로 표시
+ Ver 1.4.1: 업데이트 주기에만 평균값 계산하게 변경, 전체 코드 구조 개선, 초기 인식 이전 수치 ??로 표시
+ Ver 1.4.2: 레벨 업 시 수치가 ??로 표시되는 오류 수정
+ Ver 1.5.0: 종료 전 위치 기억, 타이머 조작 핫키{CapsLock + `(backquote)} 추가, 메소 인식 정확도 향상, 타이머 동작 중 불투명도 감소(더 투명하게)
+ Ver 1.5.1: 더 나은 정확도를 위해 레벨 ROI 방식 변경
+ Ver 1.6.0: 타이머의 기본 조작을 시작 -> 정지 -> 초기화에서 시작 -> 일시정지 -> 재개의 형태로 변경, 초기화 버튼은 상단 메뉴로 이동
+ Ver 1.6.1: 로컬 CRT DLL 번들링(MSVCP140.dll/VCRUNTIME140.dll/ucrtbase.dll/CONCRT140.dll) 및 네이티브 크래시 시 crash.log에 콜스택 기록하는 전역 예외 필터 기능 추가
+ Ver 1.7.0: 로컬 CRT DLL 번들링 제거, @myungwoo님의 기여로 N 시간 후 예상 시각 표시 기능 추가(후에 확인 결과, 일부 누락)
+ Ver 1.7.1: @myungwoo님의 기여로 누락되었던 수정 부분 추가

---

## 업데이트 예정

+ 인벤토리 창이 열려있는지 인식
+ 맥os 지원

---

## 라이센스
본 코드는 Mapleland 플레이어를 위한 개인 용도로 제공되며, 상업적/비상업적 재배포는 허용되지 않습니다.  
코드는 개인적인 수정 및 활용은 가능하나, 외부 배포 또는 상업적 이용은 금지됩니다.
