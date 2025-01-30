import sys
import cv2
import pytesseract
import numpy as np
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from PIL import Image
import mss
import win32gui
import os
import re
import uvicorn
from pydantic import BaseModel

# FastAPI 앱 생성
app = FastAPI()

# 실행 파일 경로 설정 (PyInstaller 지원)
if getattr(sys, 'frozen', False):
    base_path = sys._MEIPASS  # PyInstaller 실행 파일 내부 경로
else:
    base_path = os.path.dirname(__file__)

print(f"Base path: {base_path}")

# Tesseract-OCR 자동 감지 및 경로 설정
tesseract_path = os.path.join(base_path, "Tesseract-OCR", "tesseract.exe")
if os.path.exists(tesseract_path):
    pytesseract.pytesseract.tesseract_cmd = tesseract_path
    print(f"Tesseract Path: {tesseract_path}")
else:
    raise FileNotFoundError(f"Tesseract executable not found at {tesseract_path}")

# 리소스 파일 경로 설정
template_path_exp = os.path.join(base_path, "EXP.png")
template_path_lv = os.path.join(base_path, "LV.png")

print(f"Template paths: {template_path_exp}, {template_path_lv}")

# 템플릿 이미지 로드
template_exp = cv2.imread(template_path_exp, cv2.IMREAD_GRAYSCALE)
template_lv = cv2.imread(template_path_lv, cv2.IMREAD_GRAYSCALE)

# 윈도우 창 크기 가져오기
def get_window_rect(window_title_prefix):
    print(f"Looking for window with title starting with: {window_title_prefix}")
    
    def enum_windows_callback(hwnd_iter, result_list):
        title = win32gui.GetWindowText(hwnd_iter)
        if title.startswith(window_title_prefix):
            result_list.append((hwnd_iter, title))

    windows = []
    win32gui.EnumWindows(enum_windows_callback, windows)

    if not windows:
        raise HTTPException(status_code=404, detail=f"No windows found with title '{window_title_prefix}'")

    hwnd, title = windows[0]
    left, top, right, bottom = win32gui.GetWindowRect(hwnd)
    print(f"Window found: {title}, Rect: {left}, {top}, {right}, {bottom}")
    return {"left": left, "top": top, "width": right - left, "height": bottom - top}

# 창 캡처 함수
def capture_window_with_mss(window_title_prefix):
    print(f"Capturing window with title prefix: {window_title_prefix}")
    rect = get_window_rect(window_title_prefix)
    bottom_height = rect["height"] // 10
    monitor = {
        "top": rect["top"] + rect["height"] - bottom_height,
        "left": rect["left"],
        "width": rect["width"],
        "height": bottom_height
    }
    print(f"Capture area: {monitor}")
    
    with mss.mss() as sct:
        screenshot = sct.grab(monitor)
        img = np.array(screenshot)[:, :, :3]
        return cv2.cvtColor(np.array(img), cv2.COLOR_RGB2BGR)

# SIFT 기반 템플릿 매칭
def sift_template_matching(image, template):
    print("Starting SIFT template matching...")
    sift = cv2.SIFT_create()
    kp1, des1 = sift.detectAndCompute(template, None)
    kp2, des2 = sift.detectAndCompute(image, None)

    bf = cv2.BFMatcher()
    matches = bf.knnMatch(des1, des2, k=2)

    good_matches = [m for m, n in matches if m.distance < 0.75 * n.distance]

    if not good_matches:
        raise HTTPException(status_code=404, detail="No matches found using SIFT.")

    best_match = good_matches[0]
    pt_image = kp2[best_match.trainIdx].pt
    pt_template = kp1[best_match.queryIdx].pt
    exp_x = int(pt_image[0] - pt_template[0])
    exp_y = int(pt_image[1] - pt_template[1])
    print(f"Match found at: ({exp_x}, {exp_y})")
    return exp_x, exp_y

# EXP 값 추출
def find_exp_and_extract_number(image):
    print("Finding EXP and extracting number...")
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    exp_x, exp_y = sift_template_matching(gray, template_exp)

    exp_w, exp_h = template_exp.shape[::-1]
    number_roi = image[exp_y - 5:exp_y + exp_h + 5, exp_x + exp_w:exp_x + exp_w + 200]

    gray_roi = cv2.cvtColor(number_roi, cv2.COLOR_BGR2GRAY)
    gray_roi = cv2.resize(gray_roi, None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC)
    _, thresh = cv2.threshold(gray_roi, 150, 255, cv2.THRESH_BINARY)

    custom_config = r'--oem 3 --psm 7 -c tessedit_char_whitelist="0123456789.[]%"'
    extracted_text = pytesseract.image_to_string(thresh, config=custom_config)
    print(f"Extracted text: {extracted_text}")

    match = re.search(r"(\d+)[^\d]*(\d+\.\d+)%", extracted_text)
    if match:
        return int(match.group(1)), float(match.group(2))
    else:
        raise HTTPException(status_code=400, detail="Unable to parse EXP format.")

# LV 값 추출
def find_lv_and_extract_level(image):
    print("Finding LV and extracting level...")
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    lv_x, lv_y = sift_template_matching(gray, template_lv)

    lv_w, lv_h = template_lv.shape[::-1]
    level_roi = image[lv_y - 5:lv_y + lv_h + 5, lv_x + lv_w:lv_x + lv_w + 100]

    lower_orange = np.array([0, 50, 100])
    upper_orange = np.array([80, 255, 255])
    mask = cv2.inRange(level_roi, lower_orange, upper_orange)
    result = level_roi.copy()
    result[mask == 255] = [0, 0, 0]
    image_resized = cv2.resize(result, None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC)
    gray_resized = cv2.cvtColor(image_resized, cv2.COLOR_BGR2GRAY)
    contrast_enhanced = cv2.convertScaleAbs(gray_resized, alpha=1.5, beta=30)
    _, thresh = cv2.threshold(contrast_enhanced, 150, 255, cv2.THRESH_BINARY)
    filtered = cv2.GaussianBlur(thresh, (3, 3), 0)

    custom_config = r'--oem 3 --psm 6'
    extracted_text = pytesseract.image_to_string(filtered, lang="digits", config=custom_config)

    extracted_text = extracted_text.replace(' ', '')
    print(f"Extracted level text: {extracted_text}")

    match = re.search(r"\d+", extracted_text)
    if match:
        return int(match.group(0))
    else:
        raise HTTPException(status_code=400, detail="Unable to parse level format.")


@app.get("/extract_exp_and_level")
async def extract_exp_and_level():
    print("Starting to extract EXP and level data...")
    screenshot = capture_window_with_mss("MapleStory Worlds-Mapleland")
    exp, percentage = find_exp_and_extract_number(screenshot)
    level = find_lv_and_extract_level(screenshot)

    print(f"Extracted EXP: {exp}, Percentage: {percentage}%, Level: {level}")
    return JSONResponse(content={"exp": exp, "percentage": percentage, "level": level})

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=5000, log_config=None)

