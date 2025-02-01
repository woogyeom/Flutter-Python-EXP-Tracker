import sys
import cv2
import pytesseract
import numpy as np
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from PIL import Image
import mss
import os
import re
import uvicorn
from pydantic import BaseModel
from typing import List

# FastAPI 앱 생성
app = FastAPI()

# 전역 변수: Flutter에서 받은 ROI 좌표 저장
roi_data = {"level": None, "exp": None}

# 실행 파일 경로 설정 (PyInstaller 지원)
if getattr(sys, 'frozen', False):
    base_path = sys._MEIPASS
else:
    base_path = os.path.dirname(__file__)

print(f"Base path: {base_path}")

# Tesseract-OCR 경로 설정
tesseract_path = os.path.join(base_path, "Tesseract-OCR", "tesseract.exe")
if os.path.exists(tesseract_path):
    pytesseract.pytesseract.tesseract_cmd = tesseract_path
    print(f"Tesseract Path: {tesseract_path}")
else:
    raise FileNotFoundError(f"Tesseract executable not found at {tesseract_path}")

# ROI 데이터 구조 정의
class ROICoordinates(BaseModel):
    level: List[float]  # [x1, y1, x2, y2]
    exp: List[float]  # [x1, y1, x2, y2]

@app.post("/set_roi")
async def set_roi(roi: ROICoordinates):
    """Flutter에서 받은 ROI 데이터를 저장"""
    global roi_data
    roi_data["level"] = roi.level
    roi_data["exp"] = roi.exp
    print(f"ROI 데이터 저장됨: Level={roi.level}, EXP={roi.exp}")
    return {"message": "ROI successfully updated", "level": roi.level, "exp": roi.exp}

# ROI 기반으로 직접 캡처 수행
def capture_roi_with_mss(x1, y1, x2, y2):
    """Flutter에서 받은 ROI 좌표만 캡처"""
    monitor = {
        "top": int(y1),
        "left": int(x1),
        "width": int(x2 - x1),
        "height": int(y2 - y1)
    }

    with mss.mss() as sct:
        screenshot = sct.grab(monitor)
        img = Image.frombytes("RGB", screenshot.size, screenshot.rgb)
        return cv2.cvtColor(np.array(img), cv2.COLOR_RGB2BGR)

# OCR을 위한 전처리 함수
def preprocess_roi(roi):
    """흰색이 아닌 색을 모두 검정색으로 변환 후 OCR 최적화"""
    gray = cv2.cvtColor(roi, cv2.COLOR_BGR2GRAY)
    _, mask = cv2.threshold(gray, 200, 255, cv2.THRESH_BINARY)  # 밝은 부분 유지
    resized = cv2.resize(mask, None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC)  # 확대
    return cv2.GaussianBlur(resized, (3, 3), 0)  # 블러 추가

# LV 및 EXP 값을 ROI 기반으로 추출
def find_exp_and_lv():
    """ROI 영역을 직접 캡처하여 OCR 수행"""
    print("ROI에서 EXP 및 LV 데이터 추출 시작...")

    # ROI가 설정되지 않았다면 오류 반환
    if not roi_data["level"] or not roi_data["exp"]:
        raise HTTPException(status_code=400, detail="ROI가 설정되지 않았습니다.")

    # ROI 좌표 가져오기
    x1_lv, y1_lv, x2_lv, y2_lv = roi_data["level"]
    x1_exp, y1_exp, x2_exp, y2_exp = roi_data["exp"]

    # ROI 캡처 (Flutter에서 받은 좌표 기반)
    level_roi = capture_roi_with_mss(x1_lv, y1_lv, x2_lv, y2_lv)
    exp_roi = capture_roi_with_mss(x1_exp, y1_exp, x2_exp, y2_exp)

    # OCR을 위한 전처리
    processed_exp = preprocess_roi(exp_roi)
    processed_lv = preprocess_roi(level_roi)

    # 디버깅용 ROI 저장
    cv2.imwrite(os.path.join(base_path, "exp_roi_debug.png"), processed_exp)
    cv2.imwrite(os.path.join(base_path, "level_roi_debug.png"), processed_lv)
    
    print("EXP 및 LV ROI 저장 완료!")

    # OCR 설정 및 실행
    custom_config = r'--oem 3 --psm 7'
    extracted_exp_text = pytesseract.image_to_string(processed_exp, config=custom_config)
    extracted_lv_text = pytesseract.image_to_string(processed_lv, lang='digits', config=custom_config)

    print(f"Extracted EXP text: {extracted_exp_text}")
    print(f"Extracted Level text: {extracted_lv_text}")

    # EXP 데이터 파싱
    extracted_exp_text = re.sub(r"[^\d.%\s]", "", extracted_exp_text)
    exp_match = re.search(r"(\d+)\s*(\d+\.\d+)", extracted_exp_text)
    if exp_match:
        exp_value = int(exp_match.group(1))
        exp_percentage = float(exp_match.group(2))
    else:
        raise HTTPException(status_code=400, detail="EXP 데이터 파싱 실패")

    # LV 데이터 파싱
    extracted_lv_text = extracted_lv_text.replace(" ", "")
    lv_match = re.search(r"\d+", extracted_lv_text)
    if lv_match:
        level = int(lv_match.group(0))
    else:
        raise HTTPException(status_code=400, detail="LV 데이터 파싱 실패")

    return exp_value, exp_percentage, level

@app.get("/extract_exp_and_level")
async def extract_exp_and_level():
    """저장된 ROI 정보를 활용해 EXP 및 LV 추출"""
    print("ROI에서 EXP 및 LV 데이터 추출 시작...")
    
    if not roi_data["level"] or not roi_data["exp"]:
        raise HTTPException(status_code=400, detail="ROI가 설정되지 않았습니다.")

    try:
        exp, percentage, level = find_exp_and_lv()
        
        # EXP 및 LEVEL 유효성 검사
        if exp is None or percentage is None or level is None:
            raise HTTPException(status_code=400, detail="EXP 또는 LEVEL 데이터가 유효하지 않습니다.")

        print(f"추출 완료 - EXP: {exp}, Percentage: {percentage}%, Level: {level}")
        return JSONResponse(content={"exp": exp, "percentage": percentage, "level": level})

    except HTTPException as http_exc:
        # HTTPException을 그대로 반환 (400 오류 유지)
        raise http_exc

    except Exception as e:
        # 일반적인 예외 발생 시 500 대신 400 반환
        print(f"데이터 추출 중 오류 발생: {e}")
        raise HTTPException(status_code=400, detail=f"EXP 또는 LV 데이터 추출 실패: {e}")

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=5000, log_level="info")
