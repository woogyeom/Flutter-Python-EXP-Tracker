# MapleLand EXP Tracker

**MapleLand EXP Tracker**는 MapleLand라는 온라인 게임에서 캐릭터의 경험치 상승을 지속적으로 측정하고 시각화해주는 Flutter-Python 기반 애플리케이션입니다.  
사용자가 사냥하면서 캐릭터의 레벨 및 경험치 수치를 손쉽게 추적할 수 있도록 설계되었습니다.

---

### 앱의 구조 및 동작 과정
**MapleLand EXP Tracker**는 **Flutter**로 개발된 클라이언트 앱과 **Python 기반 FastAPI** 서버로 구성되어 있습니다.  
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

---

## 사용된 라이브러리
**Flutter**:
- [window_manager](https://pub.dev/packages/window_manager): 창을 제어하고 전체 화면 및 창 이동을 지원.
- [google_fonts](https://pub.dev/packages/google_fonts): 다양한 글꼴 스타일로 텍스트 표시.
- [http](https://pub.dev/packages/http): 서버와의 데이터 통신을 처리.
- [url_launcher](https://pub.dev/packages/url_launcher): 외부 URL 열기 기능 제공.

**Python**:
- [FastAPI](https://fastapi.tiangolo.com/): 고성능 비동기 웹 프레임워크로, API 서버 및 OCR 데이터 제공.
- [pytesseract](https://pypi.org/project/pytesseract/): Tesseract OCR 엔진으로 이미지에서 텍스트 추출.
- [mss](https://pypi.org/project/mss/): 화면 캡처를 통해 ROI 영역 이미지를 빠르게 저장.
- [uvicorn](https://www.uvicorn.org/): ASGI 서버로 FastAPI를 실행.

---

## 사용 방법
1. 앱을 실행한 뒤, 서버가 실행되는 것을 기다립니다.
2. 서버 콘솔 창에 Uvicorn running on..이라는 메시지가 표시되면, 앱 우측 상단의 ROI 설정 버튼을 누릅니다.  
3. 게임 화면의 경험치와 레벨이 표시되는 영역을 예시에 맞게 지정합니다.
4. ROI 설정이 완료되면 타이머를 시작하여 실시간 데이터를 수집합니다.  
5. 앱 화면에서 경험치 증가량, 퍼센트 상승치를 실시간으로 확인하며 사냥 효율을 분석합니다.

---

## 사용 예시 영상

[![사용 예시 영상](https://img.youtube.com/vi/87UW8UHCmyo/maxresdefault.jpg)](https://youtu.be/87UW8UHCmyo?si=BICrKtZkny5kPd5C)

위 이미지를 클릭하시면 앱의 사용 예시를 확인하실 수 있습니다.


---

## 주의 사항
1. 본 앱은 Windows 환경에서만 테스트되었습니다.
2. 게임을 저해상도로 플레이할 경우 인식 정확도가 저하될 수 있습니다.
3. 이 앱은 개인의 첫 공개 배포 개발물로, 권장된 사용 방법 외의 활용에 대한 결과는 책임지지 않습니다.
4. 본 앱은 1초마다 화면을 캡처하고 OCR을 수행하기 때문에 일정량의 메모리를 점유합니다. 따라서, 장시간 사용 시 메모리 사용량을 모니터링하고 필요 시 앱을 재실행하는 것을 권장합니다.
5. 서버 콘솔 창은 디버깅을 위해 일부러 열리게 설정되어 있습니다. 문제가 발생할 경우 콘솔 창에 표시되는 내용을 참고하여 개발자에게 공유해 주세요.

---

## 라이센스
본 코드는 MapleLand 플레이어를 위한 개인 용도로 제공되며, 상업적/비상업적 재배포는 허용되지 않습니다.  
코드는 개인적인 수정 및 활용은 가능하나, 외부 배포 또는 상업적 이용은 금지됩니다.
