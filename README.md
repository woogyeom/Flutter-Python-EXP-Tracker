# 메이플랜드 경험 측정기

![라이선스](https://img.shields.io/badge/license-All%20Rights%20Reserved-red.svg)

## 소개

이 프로젝트는 플러터와 FastAPI를 활용하여 **메이플랜드 경험치 측정기**를 구현한 것입니다.  
스크린샷을 기반으로 경험치(EXP) 및 레벨(LV)을 추출하고, 이를 실시간으로 분석하여 경험치 증가량을 모니터링합니다.

## 기술 스택

| 기술           | 사용 목적 |
|---------------|----------|
| **Flutter**   | UI 및 애플리케이션 프레임워크 |
| **Dart**      | Flutter 애플리케이션 개발 언어 |
| **Python**    | OCR 및 데이터 처리 |
| **FastAPI**   | RESTful API 서버 |
| **Tesseract-OCR** | 이미지에서 텍스트(경험치 및 레벨) 추출 |
| **OpenCV**    | 이미지 처리 및 템플릿 매칭 |
| **MSS**       | 화면 캡처 |
| **HTTP**      | Flutter ↔ FastAPI 간 데이터 통신 |

## 구성 요소

- **Flutter 앱** (`main.dart`, `homescreen.dart`)
  - UI를 제공하며, 경험치 데이터를 시각적으로 표시합니다.
- **서버** (`ocr_server.py`)
  - FastAPI로 구현된 OCR 서버로, 이미지에서 경험치와 레벨을 추출합니다.
- **OCR 유틸리티** (`ocr_util.dart`)
  - 서버로부터 경험치 데이터를 가져와 UI에 반영하는 역할을 합니다.
  - HTTP 요청을 통해 `/extract_exp_and_level` API에서 데이터를 가져오며, 실패 시 예외 처리를 수행합니다.
- **서버 매니저** (`server_manager.dart`)
  - FastAPI 서버를 실행 및 종료하는 기능을 담당합니다.
- **데이터 로더** (`exp_data_loader.dart`)
  - 레벨별 필요 경험치를 로드하여 경험치 증가량을 계산합니다.

## 유튜브 데모 영상 🎥

[![프로젝트 데모](https://github.com/user-attachments/assets/8d039abd-8158-4e37-b9be-6eb92a1dc102)](https://youtu.be/x-dRERJdxmo?si=CZx1H4GBVEfbXyvB)

프로젝트의 작동 방식과 기능을 더 자세히 알고 싶다면 위 이미지를 클릭하여 유튜브 영상을 확인하세요.

## 라이선스

본 소프트웨어는 **비상업적 용도로만 사용 가능하며, 수정은 가능하지만 재배포는 금지됩니다.**  
모든 권리는 저작자에게 있으며, 별도의 허가 없이 사용할 수 없습니다.  

- ✅ **개인 사용 가능**
- ✅ **소스 코드 수정 가능 (개인적인 용도로만)**
- ❌ **상업적 이용 금지**
- ❌ **소스 코드 및 실행 파일 재배포 금지**
- ❌ **공유 및 배포 금지**

> 수정한 버전도 재배포할 수 없습니다.  
> 문의 사항이 있을 경우 아래 이메일로 연락 바랍니다.

## 문의

프로젝트에 대한 문의는 [이메일 주소](mailto:woogyeom99@gmail.com)로 연락주세요.
