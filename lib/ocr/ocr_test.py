from datetime import datetime
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
    base_path = sys._MEIPASS
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

# CLAHE 객체 생성
clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8,8))

# CLAHE 적용하여 고대비 처리
template_exp = clahe.apply(template_exp)
template_lv = clahe.apply(template_lv)

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
        img = Image.frombytes("RGB", screenshot.size, screenshot.rgb)
        return cv2.cvtColor(np.array(img), cv2.COLOR_RGB2BGR)
    
# SIFT 기반 템플릿 매칭 (스케일 감지 추가)
def sift_template_matching(image, template):
    print("Starting SIFT template matching...")
    
    # Grayscale 변환
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    
    # CLAHE 적용하여 고대비 처리
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8,8))
    gray = clahe.apply(gray)

    # SIFT 객체 생성 및 키포인트 검출
    sift = cv2.SIFT_create()
    kp1, des1 = sift.detectAndCompute(template, None)
    kp2, des2 = sift.detectAndCompute(gray, None)

    if des1 is None or des2 is None:
        raise HTTPException(status_code=404, detail="No descriptors found.")

    # FLANN 매처 설정
    FLANN_INDEX_KDTREE = 1
    index_params = dict(algorithm=FLANN_INDEX_KDTREE, trees=5)
    search_params = dict(checks=50)
    flann = cv2.FlannBasedMatcher(index_params, search_params)

    # 매칭
    matches = flann.knnMatch(des1, des2, k=2)
    # 비율 테스트
    good_matches = []
    for m, n in matches:
        if m.distance < 0.7 * n.distance:
            good_matches.append(m)

    if len(good_matches) < 4:
        raise HTTPException(status_code=404, detail="Not enough matches for homography.")

    # 매칭된 위치 계산
    best_match = good_matches[0]
    pt_image = kp2[best_match.trainIdx].pt
    pt_template = kp1[best_match.queryIdx].pt
    found_x = int(pt_image[0] - pt_template[0])
    found_y = int(pt_image[1] - pt_template[1])

    print(f"Match found at: ({found_x}, {found_y})")

    # 디버깅 이미지 저장
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    debug_filename = f"{timestamp}.png"
    debug_path = os.path.join(base_path, debug_filename)
    debug_image = cv2.drawMatches(template, kp1, gray, kp2, good_matches, None)
    cv2.imwrite(debug_path, debug_image)
    print(f"Debug image saved to {debug_path}")

    return found_x, found_y

# LV와 EXP를 동시에 매칭하여 스케일 보정
def find_exp_and_lv(image):
    print("Finding EXP and LV data...")

    exp_x, exp_y = sift_template_matching(image, template_exp)
    lv_x, lv_y = sift_template_matching(image, template_lv)

    # EXP 값 추출
    exp_w, exp_h = template_exp.shape[::-1]

    number_roi = image[
        exp_y - 5:exp_y + exp_h + 5,
        exp_x + exp_w - int(50):exp_x + exp_h + int(180)
    ]

    gray_roi = cv2.cvtColor(number_roi, cv2.COLOR_BGR2GRAY)
    gray_roi = cv2.resize(gray_roi, None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC)
    _, thresh = cv2.threshold(gray_roi, 150, 255, cv2.THRESH_BINARY)
    filtered = cv2.GaussianBlur(thresh, (3, 3), 0)

    # 디버깅용 ROI 저장
    debug_save_path = os.path.join(base_path, "exp_roi_debug.png")
    cv2.imwrite(debug_save_path, filtered)
    print(f"Processed EXP ROI saved at {debug_save_path}")

    custom_config = r'--oem 3 --psm 7 -c tessedit_char_whitelist="0123456789.[]%"'
    extracted_text = pytesseract.image_to_string(thresh, config=custom_config)
    print(f"Extracted EXP text: {extracted_text}")

    match = re.search(r"(\d+)[^\d]*(\d+\.\d+)%", extracted_text)
    if match:
        exp_value = int(match.group(1))
        exp_percentage = float(match.group(2))
    else:
        raise HTTPException(status_code=400, detail="Unable to parse EXP format.")

    # LV 값 추출
    lv_w, lv_h = template_lv.shape[::-1]

    level_roi = image[
        lv_y:lv_y + lv_h + 5,
        lv_x + lv_w:lv_x + lv_w + 100
    ]
    
    # HSV 변환
    hsv_roi = cv2.cvtColor(level_roi, cv2.COLOR_BGR2HSV)
    h, s, v = cv2.split(hsv_roi)

    # Saturation이 120 이하인 영역을 유지, 나머지는 검은색 처리
    mask = cv2.inRange(s, 0, 120)
    result = cv2.bitwise_and(level_roi, level_roi, mask=mask)

    # 이미지 확대 및 전처리
    image_resized = cv2.resize(result, None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC)
    gray_resized = cv2.cvtColor(image_resized, cv2.COLOR_BGR2GRAY)
    contrast_enhanced = cv2.convertScaleAbs(gray_resized, alpha=1.5, beta=30)
    _, thresh = cv2.threshold(contrast_enhanced, 150, 255, cv2.THRESH_BINARY)
    filtered = cv2.GaussianBlur(thresh, (3, 3), 0)

    # 디버깅용 ROI 저장
    debug_save_path = os.path.join(base_path, "level_roi_debug.png")
    cv2.imwrite(debug_save_path, filtered)
    print(f"Processed Level ROI saved at {debug_save_path}")

    custom_config = r'--oem 3 --psm 7'
    extracted_text = pytesseract.image_to_string(thresh, lang="digits", config=custom_config)
    extracted_text = extracted_text.replace(' ', '')
    print(f"Extracted level text: {extracted_text}")

    match = re.search(r"\d+", extracted_text)
    if match:
        level = int(match.group(0))
    else:
        raise HTTPException(status_code=400, detail="Unable to parse level format.")

    return exp_value, exp_percentage, level

@app.get("/extract_exp_and_level")
async def extract_exp_and_level():
    print("Starting to extract EXP and level data...")
    screenshot = capture_window_with_mss("MapleStory Worlds-Mapleland")
    exp, percentage, level = find_exp_and_lv(screenshot)

    return JSONResponse(content={"exp": exp, "percentage": percentage, "level": level})

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=5000, log_config=None)
