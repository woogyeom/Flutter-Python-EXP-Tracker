import sys
import threading
import time
import cv2
import pytesseract
import numpy as np
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from PIL import Image
import mss
import os
import re
import zipfile
import logging
from pydantic import BaseModel
from typing import List, Optional
from contextlib import asynccontextmanager
import asyncio

if getattr(sys, 'frozen', False):
    base_path = sys._MEIPASS
    debug_base_path = os.path.abspath(os.path.join(sys._MEIPASS, os.pardir))
else:
    base_path = os.path.dirname(__file__)
    debug_base_path = base_path

# 로거 설정
logger = logging.getLogger("my_logger")
logger.setLevel(logging.DEBUG)
console_handler = logging.StreamHandler()

# debug_base_path를 사용해 절대 경로 지정
log_file_path = os.path.join(debug_base_path, "server_log.txt")
file_handler = logging.FileHandler(log_file_path, encoding="utf-8")

formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
console_handler.setFormatter(formatter)
file_handler.setFormatter(formatter)
logger.addHandler(console_handler)
logger.addHandler(file_handler)

logger.info(f"Base path: {base_path}")

# Tesseract-OCR 경로 설정
tesseract_path = os.path.join(base_path, "Tesseract-OCR", "tesseract.exe")
if os.path.exists(tesseract_path):
    pytesseract.pytesseract.tesseract_cmd = tesseract_path
    logger.info(f"Tesseract Path: {tesseract_path}")
else:
    raise FileNotFoundError(f"Tesseract executable not found at {tesseract_path}")

# ROI 데이터 구조 정의
class ROICoordinates(BaseModel):
    level: List[float]  # [x1, y1, x2, y2]
    exp: List[float]    # [x1, y1, x2, y2]
    meso: Optional[List[float]] = None

# Lifespan 컨텍스트 매니저를 활용한 시작/종료 작업 처리
@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("서버 시작")
    yield
    # 서버 종료 시 실행할 작업
    logger.info("서버 종료 중: 로그 파일 저장 완료")
    if os.path.exists("server_logs.txt"):
        logger.info("로그 파일이 저장되었습니다: server_logs.txt")
    logger.info("서버 종료 작업 완료")
    logging.shutdown()

# FastAPI 앱 생성 시 lifespan 매니저 지정
app = FastAPI(lifespan=lifespan)

# 전역 변수: Flutter에서 받은 ROI 좌표 저장
roi_data = {"level": None, "exp": None, "meso": None}

@app.get("/health")
async def health():
    return {"status": "ok"}

@app.post("/set_roi")
async def set_roi(roi: ROICoordinates):
    global roi_data
    roi_data["level"] = roi.level
    roi_data["exp"] = roi.exp
    response_data = {
        "message": "ROI successfully updated",
        "level": roi.level,
        "exp": roi.exp
    }
    if roi.meso is not None:
        roi_data["meso"] = roi.meso
        logger.info(f"ROI 데이터 수신 (메소 포함): Level={roi.level}, EXP={roi.exp}, MESO={roi.meso}")
        response_data["meso"] = roi.meso
    else:
        logger.info(f"ROI 데이터 수신: Level={roi.level}, EXP={roi.exp}")
    return response_data

def capture_roi_with_mss(x1, y1, x2, y2):
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

def preprocess_roi(roi):
    gray = cv2.cvtColor(roi, cv2.COLOR_BGR2GRAY)
    _, mask = cv2.threshold(gray, 180, 255, cv2.THRESH_BINARY)
    resized = cv2.resize(mask, None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC)
    return cv2.GaussianBlur(resized, (3, 3), 0)

def find_exp_and_lv():
    logger.info("ROI에서 EXP 및 LV 데이터 추출 시작...")
    if not roi_data["level"] or not roi_data["exp"]:
        raise HTTPException(status_code=400, detail="ROI가 설정되지 않았습니다.")
    
    x1_lv, y1_lv, x2_lv, y2_lv = roi_data["level"]
    x1_exp, y1_exp, x2_exp, y2_exp = roi_data["exp"]
    
    level_roi = capture_roi_with_mss(x1_lv, y1_lv, x2_lv, y2_lv)
    exp_roi = capture_roi_with_mss(x1_exp, y1_exp, x2_exp, y2_exp)
    
    processed_exp = preprocess_roi(exp_roi)
    processed_lv = preprocess_roi(level_roi)
    
    cv2.imwrite(os.path.join(debug_base_path, "exp_roi_debug.png"), processed_exp)
    cv2.imwrite(os.path.join(debug_base_path, "level_roi_debug.png"), processed_lv)
    
    custom_config = r'--oem 3 --psm 7'
    extracted_exp_text_debug = pytesseract.image_to_string(processed_exp, lang='digits', config=custom_config)
    extracted_lv_text_debug = pytesseract.image_to_string(processed_lv, lang='digits', config=custom_config)
    
    logger.info(f"추출된 경험치 텍스트: {extracted_exp_text_debug}")
    logger.info(f"추출된 레벨 텍스트: {extracted_lv_text_debug}")
    
    extracted_exp_text_debug = extracted_exp_text_debug.encode("utf-8", errors="ignore").decode("utf-8")
    extracted_lv_text_debug = extracted_lv_text_debug.encode("utf-8", errors="ignore").decode("utf-8")
    
    extracted_exp_text = re.sub(r"[^\d.%\s]", "", extracted_exp_text_debug)
    exp_match = re.search(r"(\d+)\s*(\d+\.\d+)", extracted_exp_text)
    if exp_match:
        exp_value = int(exp_match.group(1))
        exp_percentage = float(exp_match.group(2))
    else:
        cv2.imwrite(os.path.join(debug_base_path, "exp_roi_debug_error.png"), processed_exp)
        raise HTTPException(status_code=400, detail=f"EXP 데이터 파싱 실패: '{extracted_exp_text_debug}'")
    
    extracted_lv_text = extracted_lv_text_debug.replace(" ", "")
    lv_match = re.search(r"\d+", extracted_lv_text)
    if lv_match:
        level = int(lv_match.group(0))
    else:
        cv2.imwrite(os.path.join(debug_base_path, "level_roi_debug_error.png"), processed_lv)
        raise HTTPException(status_code=400, detail=f"LV 데이터 파싱 실패: '{extracted_lv_text_debug}'")
    
    return exp_value, exp_percentage, level

def find_meso():
    logger.info("ROI에서 메소 데이터 추출 시작...")
    if not roi_data["meso"]:
        raise HTTPException(status_code=400, detail="ROI가 설정되지 않았습니다.")
    
    x1_meso, y1_meso, x2_meso, y2_meso = roi_data["meso"]
    
    meso_roi = capture_roi_with_mss(x1_meso, y1_meso, x2_meso, y2_meso)
    
    processed_meso = preprocess_roi(meso_roi)
    
    cv2.imwrite(os.path.join(debug_base_path, "meso_roi_debug.png"), processed_meso)
    
    custom_config = r'--oem 3 --psm 7'
    extracted_meso_text_debug = pytesseract.image_to_string(processed_meso, lang='digits', config=custom_config)

    logger.info(f"추출된 메소 텍스트: {extracted_meso_text_debug}")
    
    extracted_meso_text_debug = extracted_meso_text_debug.encode("utf-8", errors="ignore").decode("utf-8")
    
    extracted_meso_text = re.sub(r"[^\d]", "", extracted_meso_text_debug)  # 숫자만 남기고 제거
    meso_match = re.search(r"\d+", extracted_meso_text)  # 순수 숫자만 추출
    if meso_match:
        meso = int(meso_match.group(0))
    else:
        cv2.imwrite(os.path.join(debug_base_path, "meso_roi_debug_error.png"), processed_meso)
        raise HTTPException(status_code=400, detail=f"메소 데이터 파싱 실패: '{extracted_meso_text_debug}'")
    
    return meso

@app.get("/extract_exp_and_level")
async def extract_exp_and_level():
    logger.info("ROI에서 EXP 및 LV 데이터 추출 요청 수신")
    if not roi_data["level"] or not roi_data["exp"]:
        raise HTTPException(status_code=400, detail="ROI가 설정되지 않았습니다.")
    try:
        exp, percentage, level = find_exp_and_lv()
        if exp is None or percentage is None or level is None:
            raise HTTPException(status_code=400, detail="EXP 또는 LEVEL 데이터가 유효하지 않습니다.")
        logger.info(f"추출 완료 - EXP: {exp}, Percentage: {percentage}%, Level: {level}")
        return JSONResponse(content={"exp": exp, "percentage": percentage, "level": level})
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        logger.error(f"데이터 추출 중 오류 발생: {e}")
        raise HTTPException(status_code=400, detail=f"EXP 또는 LV 데이터 추출 실패: {e}")
    
@app.get("/extract_meso")
async def extract_meso():
    logger.info("ROI에서 메소 데이터 추출 요청 수신")
    if not roi_data["meso"]:
        raise HTTPException(status_code=400, detail="ROI가 설정되지 않았습니다.")
    try:
        meso = find_meso()
        if meso is None:
            raise HTTPException(status_code=400, detail="메소 데이터가 유효하지 않습니다.")
        logger.info(f"추출 완료 - 메소: {meso}")
        return JSONResponse(content={"meso": meso})
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        logger.error(f"데이터 추출 중 오류 발생: {e}")
        raise HTTPException(status_code=400, detail=f"메소 데이터 추출 실패: {e}")

@app.get("/shutdown")
async def shutdown():
    """
    /shutdown 엔드포인트 호출 시 uvicorn 서버 인스턴스의 should_exit 플래그를 True로 설정하여
    graceful shutdown을 유도합니다.
    """
    logger.info("서버 종료 명령 수신, 종료 절차 진행 (graceful shutdown)")
    # app.state.server는 uvicorn.Server 인스턴스를 가리킵니다.
    app.state.server.should_exit = True
    return {"message": "Server is shutting down gracefully."}

# uvicorn.Server를 직접 사용하여 앱 실행
if __name__ == "__main__":
    from uvicorn import Config, Server
    config = Config(app, host="127.0.0.1", port=5000, log_level="info", lifespan="on")
    server = Server(config)
    # 앱 상태에 서버 인스턴스를 저장해서 shutdown 엔드포인트에서 참조할 수 있게 함
    app.state.server = server
    server.run()
