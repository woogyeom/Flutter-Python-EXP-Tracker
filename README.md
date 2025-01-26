# Flutter + Python(Flask) + OpenCV(Tesseract OCR) 프로젝트

이 프로젝트는 **게임 화면 내의 EXP, 레벨 정보를 자동으로 추출**하여, **Flutter 앱(프론트엔드)에서 실시간으로 확인**할 수 있게 하는 시스템입니다.

<br />

## 구성 요소

1. **[Python + OpenCV + Tesseract OCR]**  
   - 게임 화면(예: “MapleStory Worlds-Mapleland”)을 **MSS** 라이브러리로 스크린 캡처  
   - **SIFT(Scale-Invariant Feature Transform)** 알고리즘을 사용한 템플릿 매칭으로 EXP / LV 아이콘의 위치를 찾음  
   - 템플릿 매칭으로 찾아낸 위치 주변을 잘라 **Tesseract**로 OCR(문자 인식)  
   - 인식된 데이터를 **Flask** 서버에서 **JSON 형태**로 응답

2. **[Flutter 클라이언트]**  
   - 주기적으로 Flask 서버에 **HTTP 요청**을 보내어, EXP·퍼센트·레벨 등의 정보를 받아옴  
   - **Cupertino UI** 기반으로 데이터를 시각화  
   - **Timer**를 이용해 플레이 시간 측정 및 EXP 누적 계산  
   - **서버 상태**(정상/에러)를 UI 인디케이터(초록/빨강)로 표시  
   - **서버 프로세스**(`ocr_server.exe`)를 실행/종료하는 기능 제공

---
유튜브 영상
[![사용 동영상](https://github.com/user-attachments/assets/b752d61e-040b-4041-b48c-94c8a803d8dd)](https://youtu.be/AExURzDv2UE?si=pqfsEcTX5duZP2kD)

---

## 기술 스택

- **언어**: Dart(Flutter), Python
- **프레임워크**: Flask (Python)
- **라이브러리**:
  - Python: `OpenCV`, `pytesseract`, `mss`, `win32gui`, `numpy`
  - Flutter: `http`, `google_fonts`, `cupertino_icons`
- **이미지 처리**: OpenCV (SIFT 알고리즘, 템플릿 매칭), Tesseract OCR
- **배포**: Python Flask 서버를 `ocr_server.exe`로 빌드 후, Flutter에서 실행/종료 관리

---

## 동작 방식

1. **Python 서버 (Flask)**
   1. **창 정보 탐색**  
      - `win32gui`를 통해 `"MapleStory Worlds-Mapleland"`라는 제목의 윈도우 식별  
      - 해당 윈도우의 `(left, top, width, height)` 좌표를 가져옴

   2. **화면 캡처**  
      - `mss` 라이브러리를 사용해 윈도우 특정 영역만 캡처  
      - 캡처 영역은 주로 하단 UI 부분(`height // 10`)으로 설정

   3. **템플릿 매칭(SIFT)**  
      - `cv2.SIFT_create()`로 이미지 특징점(Keypoint) 추출  
      - `EXP.png`, `LV.png` 같은 템플릿 이미지와 비교하여 EXP 아이콘, LV 아이콘 위치를 찾음  
      - 최종 매칭 좌표(`exp_x, exp_y` / `lv_x, lv_y`)를 이용해 OCR 영역 결정

   4. **OCR (Tesseract)**
      - 템플릿 매칭으로 얻은 좌표 주변을 잘라 `pytesseract.image_to_string()`에 전달  
      - `--psm 7 -c tessedit_char_whitelist="0123456789.[]%` 등 옵션으로 불필요한 문자를 거른 뒤 인식  
      - `re`(정규 표현식)로 `966186 [88.84%]` 형태에서 EXP값과 퍼센트를 파싱  
      - 레벨(`LV`) 영역에서는 `digits` 언어를 사용해 숫자만 인식 후 레벨 파싱

   5. **JSON 응답**  
      - 최종적으로 `{"exp": <int>, "percentage": <float>, "level": <int>}` 형태의 JSON 데이터를 Flask에서 응답

2. **Flutter 앱**
   1. **HTTP 요청**  
      - `ExpFetcher` 클래스로 Python Flask 서버(`http://127.0.0.1:5000/extract_exp_and_level`)에 GET 요청  
      - 응답 데이터(JSON)를 파싱하고, `exp`, `percentage`, `level`을 추출

   2. **UI/Timer**  
      - `Timer.periodic`(1초 간격)으로 서버에 반복 요청을 보내 실시간으로 값을 업데이트  
      - 시작/중단/초기화 버튼을 이용해 타이머를 제어(플레이 시간, 획득 EXP 누적량 계산)  

   3. **서버 상태 표시**  
      - 요청이 성공하면 상태 `connected`, 실패(Timeout 등) 시 `error`  
      - UI 왼쪽 상단에 초록/빨강 원형 인디케이터로 표시

   4. **서버 프로세스(`ocr_server.exe`)**  
      - `ServerManager` 클래스로 별도 EXE 프로세스를 실행/종료  
      - Windows CMD 명령어(`tasklist`, `taskkill`)로 특정 프로세스(`ocr_server.exe`)를 조회 후 강제 종료

---

## 주의 사항

- **윈도우 제목**  
  현재 예시는 `"MapleStory Worlds-Mapleland"`라는 제목으로 창을 찾습니다. 다른 게임/프로그램에 적용하려면 `get_window_rect(window_title_prefix)` 부분의 문자열을 변경해야 합니다.
  
- **해상도/UI 차이**  
  템플릿 매칭은 해상도나 UI 요소가 달라지면 인식률이 떨어질 수 있습니다. 현재 템플릿 이미지(`EXP.png`, `LV.png`)는 1600*900이상의 해상도에서 테스트되었습니다.

- **Tesseract 인식률**  
  OCR 결과가 불안정할 수 있으므로, 전처리(이진화, 블러, 대비 조정) 및 `tessedit_char_whitelist` 설정 등 세부 조정이 필요할 수 있습니다.

- **운영체제**  
  `win32gui`, `tasklist`, `taskkill` 명령어를 사용하므로 Windows 환경을 전제로 합니다.
