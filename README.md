# MapleLand EXP Tracker

**MapleLand EXP Tracker**는 MapleLand라는 온라인 게임에서 캐릭터의 경험치 상승을 지속적으로 측정하고 시각화해주는 Flutter-Python 기반 애플리케이션입니다.  
사용자가 사냥하면서 캐릭터의 레벨 및 경험치 수치를 손쉽게 추적할 수 있도록 설계되었습니다.

---

## 주요 기능
- **Flutter 앱**:  
  - 사용자 친화적인 인터페이스를 통해 경험치 및 레벨 데이터를 실시간으로 표시.  
  - 경험치 획득 데이터를 시각화하고 증가량 및 퍼센트를 계산.  
  - ROI(Region of Interest) 설정 화면을 통해 게임 내 특정 UI 영역을 선택 가능.
  - 타이머를 시작, 멈춤, 초기화하면서 경험치 획득 속도를 측정.

- **Python 서버**:  
  - FastAPI를 기반으로 클라이언트와 통신하며, 실시간으로 데이터 처리를 수행.  
  - Flutter 앱에서 전송된 ROI 좌표를 기준으로 게임 UI에서 경험치 및 레벨 데이터를 추출.  
  - Tesseract OCR을 활용해 이미지 내 텍스트를 읽어 정확한 경험치 값을 분석.  
  - 사용자가 ROI를 설정한 후, 자동으로 캡처 및 OCR 과정을 진행하여 데이터를 반환.

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
1. 앱을 실행한 뒤, 우측 상단의 ROI 설정 버튼을 누릅니다.  
2. 게임 화면의 경험치와 레벨이 표시되는 영역을 지정합니다.  
3. ROI 설정이 완료되면 타이머를 시작하여 실시간 데이터를 수집합니다.  
4. 앱 화면에서 경험치 증가량, 퍼센트 상승치를 실시간으로 확인하며 사냥 효율을 분석합니다.

---

## 사용 예시 영상

[![사용 예시 영상](https://img.youtube.com/vi/Ia1Gz95vIlc/maxresdefault.jpg)](https://youtu.be/Ia1Gz95vIlc?si=MjTNnO1jwr5yz5aG)

위 이미지를 클릭하시면 앱의 사용 예시를 확인하실 수 있습니다.


---

## 주의 사항
1. 본 앱은 Windows 환경에서만 동작합니다.
2. 게임을 저해상도로 플레이할 경우 인식 정확도가 저하될 수 있습니다.
3. 이 앱은 개인의 첫 공개 배포 개발물로, 권장된 사용 방법 외의 활용에 대한 결과는 책임지지 않습니다.
4. 서버 콘솔 창은 디버깅을 위해 일부러 열리게 설정되어 있습니다. 문제가 발생할 경우 콘솔 창에 표시되는 내용을 참고하여 개발자에게 공유해 주세요.

---

## 라이센스
본 코드는 MapleLand 플레이어를 위한 개인 용도로 제공되며, 상업적/비상업적 재배포는 허용되지 않습니다.  
코드는 개인적인 수정 및 활용은 가능하나, 외부 배포 또는 상업적 이용은 금지됩니다.
