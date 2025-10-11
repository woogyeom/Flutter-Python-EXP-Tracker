import os
import re
import datetime
import codecs
import signal
import sys
import cv2
import pytesseract
import numpy as np
import mss
from PIL import Image
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from typing import List, Optional
from pydantic import BaseModel
from contextlib import asynccontextmanager
import uvicorn

##############################################################################
# 1) LOGGING (safe_log, _cleanupOldLogs)
##############################################################################

LOG_DIR = r"C:\temp\MaplelandEXPTracker"

def _cleanupOldLogs():
    """
    3일보다 오래된 server_log_YYYY-MM-DD.txt 파일들을 삭제한다.
    """
    if not os.path.exists(LOG_DIR):
        return
    now = datetime.datetime.now()
    files = os.listdir(LOG_DIR)
    for entry in files:
        if entry.startswith("server_log_") and entry.endswith(".txt"):
            match = re.match(r'^server_log_(\d{4}-\d{2}-\d{2})\.txt$', entry)
            if match:
                file_date_str = match.group(1)
                try:
                    file_date = datetime.datetime.strptime(file_date_str, "%Y-%m-%d")
                    if (now - file_date).days > 3:
                        os.remove(os.path.join(LOG_DIR, entry))
                except ValueError:
                    pass

def safe_log(message: str):
    """
    날짜별 로그 파일에 로그를 기록
    """
    now = datetime.datetime.now()
    formatted_dt = now.strftime("%Y-%m-%d %H:%M:%S")
    log_line = f"{formatted_dt} - {message}\n"

    if not os.path.exists(LOG_DIR):
        os.makedirs(LOG_DIR)
    
    date_str = now.strftime("%Y-%m-%d")
    log_file_name = f"server_log_{date_str}.txt"
    file_path = os.path.join(LOG_DIR, log_file_name)

    if not os.path.exists(file_path):
        with open(file_path, "wb") as f:
            f.write(codecs.BOM_UTF8)
            f.write(log_line.encode("utf-8"))
    else:
        with open(file_path, "rb") as f:
            first_bytes = f.read(3)
        if first_bytes != codecs.BOM_UTF8:
            with open(file_path, "rb") as f:
                old_data = f.read()
            with open(file_path, "wb") as f:
                f.write(codecs.BOM_UTF8)
                f.write(old_data)
        with open(file_path, "ab") as f:
            f.write(log_line.encode("utf-8"))

    _cleanupOldLogs()
    print(log_line, end="")

##############################################################################
# 2) Tesseract, OCR, ROI 추출
##############################################################################

if sys.stdout is None:
    sys.stdout = sys.__stdout__
if sys.stderr is None:
    sys.stderr = sys.__stderr__

if getattr(sys, 'frozen', False):
    base_path = sys._MEIPASS
    debug_base_path = os.path.abspath(os.path.join(sys._MEIPASS, os.pardir))
else:
    base_path = os.path.dirname(__file__)
    debug_base_path = base_path

tesseract_path = os.path.join(base_path, "Tesseract-OCR", "tesseract.exe")
if os.path.exists(tesseract_path):
    pytesseract.pytesseract.tesseract_cmd = tesseract_path
    safe_log(f"Tesseract Path: {tesseract_path}")
else:
    raise FileNotFoundError(f"Tesseract executable not found at {tesseract_path}")

def capture_roi_with_mss(x1, y1, x2, y2):
    """
    x1, y1, x2, y2 영역을 mss로 캡처하여 OpenCV BGR 이미지로 반환
    """
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

# <<<수정>>> 마스킹 코드로 되돌리고, 경로 수정은 유지
def preprocess_roi(roi, debug_filename: str = None):
    """
    ROI 이미지에서 흰색 계열을 마스킹하여 전처리하고, 
    debug_filename이 주어지면 저장
    """
    # 1. BGR 색상 모델을 HSV로 변경
    hsv = cv2.cvtColor(roi, cv2.COLOR_BGR2HSV)

    # 2. 흰색의 HSV 범위 정의
    lower_white = np.array([0, 0, 180])
    upper_white = np.array([255, 50, 255])

    # 3. cv2.inRange()를 이용해 마스크 생성 (흰색 글자만 남김)
    mask = cv2.inRange(hsv, lower_white, upper_white)

    # 4. 후속 처리
    resized = cv2.resize(mask, None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC)
    processed_image = cv2.GaussianBlur(resized, (3, 3), 0)
    
    # if debug_filename:
    #     # py 파일 위치를 기준으로 'debug_images' 폴더 경로 지정
    #     save_dir = os.path.join(debug_base_path, "debug_images")
        
    #     # 폴더가 없으면 생성
    #     if not os.path.exists(save_dir):
    #         os.makedirs(save_dir)
            
    #     # 파일 저장
    #     now_str = datetime.datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    #     save_path = os.path.join(save_dir, f"{debug_filename}_{now_str}.png")
    #     cv2.imwrite(save_path, processed_image)
        
    return processed_image


##############################################################################
# 3) FastAPI 서버
##############################################################################

class ROICoordinates(BaseModel):
    level: List[float]
    exp: List[float]
    meso: Optional[List[float]] = None

roi_data = {"level": None, "exp": None, "meso": None}

app = FastAPI()

@app.on_event("startup")
async def on_startup():
    safe_log("서버 시작")

@app.on_event("shutdown")
async def on_shutdown():
    safe_log("서버 종료 중: 로그 파일 저장 완료")
    safe_log("서버 종료 작업 완료")

@app.get("/health")
async def health():
    safe_log("Health check 요청 수신")
    return {"status": "ok"}

@app.post("/set_roi")
async def set_roi(roi: ROICoordinates):
    global roi_data
    roi_data["level"] = roi.level
    roi_data["exp"] = roi.exp
    roi_data["meso"] = roi.meso
    safe_log(f"ROI 데이터 수신: Level={roi.level}, EXP={roi.exp}, MESO={roi.meso}")
    return {"message": "ROI successfully updated", "level": roi.level, "exp": roi.exp, "meso": roi.meso}

@app.get("/extract_exp_and_level")
async def extract_exp_and_level():
    if not roi_data["level"] or not roi_data["exp"]:
        raise HTTPException(status_code=400, detail="ROI가 설정되지 않았습니다.")
    try:
        x1_lv, y1_lv, x2_lv, y2_lv = roi_data["level"]
        x1_exp, y1_exp, x2_exp, y2_exp = roi_data["exp"]

        level_roi = capture_roi_with_mss(x1_lv, y1_lv, x2_lv, y2_lv)
        exp_roi = capture_roi_with_mss(x1_exp, y1_exp, x2_exp, y2_exp)
        
        processed_lv = preprocess_roi(level_roi, debug_filename="level")
        processed_exp = preprocess_roi(exp_roi, debug_filename="exp")

        custom_lv_config = r'--oem 3 --psm 7 whitelist=0123456789'
        custom_exp_config = r'--oem 3 --psm 7'
        extracted_lv_text = pytesseract.image_to_string(processed_lv, lang='digits', config=custom_lv_config)
        extracted_exp_text = pytesseract.image_to_string(processed_exp, lang='digits', config=custom_exp_config)

        safe_log(f"추출된 레벨 텍스트: {extracted_lv_text.strip()}")
        safe_log(f"추출된 경험치 텍스트: {extracted_exp_text.strip()}")
        
        extracted_exp_text = re.sub(r"[^\d.%\s]", "", extracted_exp_text)
        exp_match = re.search(r"(\d+)\s*(\d+\.\d+)", extracted_exp_text)
        if not exp_match:
            raise HTTPException(status_code=400, detail=f"EXP 데이터 파싱 실패: '{extracted_exp_text}'")
        exp_value = int(exp_match.group(1))
        exp_percentage = float(exp_match.group(2))

        extracted_lv_text = re.sub(r"[^\d]", "", extracted_lv_text)
        lv_match = re.search(r"(\d+)", extracted_lv_text)
        if not lv_match:
            raise HTTPException(status_code=400, detail=f"LV 데이터 파싱 실패: '{extracted_lv_text}'")
        level = int(lv_match.group(1))

        safe_log(f"추출 완료 - EXP: {exp_value}, Percentage: {exp_percentage}%, Level: {level}")
        return {"exp": exp_value, "percentage": exp_percentage, "level": level}
    except HTTPException as e:
        raise e
    except Exception as e:
        safe_log(f"[Server] Error fetching EXP data: {e}")
        raise HTTPException(status_code=400, detail=f"EXP 또는 LV 데이터 추출 실패: {e}")

@app.get("/extract_meso")
async def extract_meso():
    if not roi_data["meso"]:
        raise HTTPException(status_code=400, detail="ROI가 설정되지 않았습니다.")
    try:
        x1_m, y1_m, x2_m, y2_m = roi_data["meso"]
        meso_roi = capture_roi_with_mss(x1_m, y1_m, x2_m, y2_m)
        
        processed_meso = preprocess_roi(meso_roi, debug_filename="meso")

        custom_config = r'--oem 3 --psm 7 whitelist=0123456789'
        extracted_meso_text = pytesseract.image_to_string(processed_meso, lang='digits', config=custom_config)
        safe_log(f"추출된 메소 텍스트: {extracted_meso_text.strip()}")
        
        extracted_meso_text = re.sub(r"[^\d]", "", extracted_meso_text)
        if not extracted_meso_text.isdigit():
            raise HTTPException(status_code=400, detail=f"메소 데이터 파싱 실패: '{extracted_meso_text}'")
        meso = int(extracted_meso_text)
        
        safe_log(f"추출 완료 - 메소: {meso}")
        return {"meso": meso}
    except HTTPException as e:
        raise e
    except Exception as e:
        safe_log(f"[Server] Error fetching Meso data: {e}")
        raise HTTPException(status_code=400, detail=f"메소 데이터 추출 실패: {e}")

@app.get("/")
async def root():
    return {"message": "Server is running"}

@app.get("/shutdown")
async def shutdown():
    safe_log("Shutting down the server via /shutdown endpoint...")
    os.kill(os.getpid(), signal.SIGTERM)
    return {"detail": "Shutdown signal sent"}

##############################################################################
# 4) 메인 실행부 (uvicorn)
##############################################################################
if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=5000, log_level="info", reload=False, use_colors=False)