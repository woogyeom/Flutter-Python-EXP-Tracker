import sys
import cv2
import pytesseract
import numpy as np
from flask import Flask, jsonify
from PIL import Image
import mss
import win32gui
import os
import uuid
import re
import os
import sys

app = Flask(__name__)

# 리소스 경로 설정
if getattr(sys, 'frozen', False):
    # PyInstaller로 빌드된 실행 파일 내에서 리소스 경로를 가져옴
    base_path = sys._MEIPASS  # 실행 파일 내부 경로
else:
    # 개발 환경에서의 경로
    base_path = os.path.dirname(__file__)

print(f"Base path: {base_path}")

# 리소스 파일 경로
template_path_exp = os.path.join(base_path, 'EXP.png')
template_path_lv = os.path.join(base_path, 'LV.png')

print(f"Template paths: {template_path_exp}, {template_path_lv}")

template_exp = cv2.imread(template_path_exp, cv2.IMREAD_GRAYSCALE)
template_lv = cv2.imread(template_path_lv, cv2.IMREAD_GRAYSCALE)

pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'

def get_window_rect(window_title_prefix):
    print(f"Looking for window with title starting with: {window_title_prefix}")
    hwnd = None

    def enum_windows_callback(hwnd_iter, result_list):
        title = win32gui.GetWindowText(hwnd_iter)
        if title.startswith(window_title_prefix):
            result_list.append((hwnd_iter, title))

    windows = []
    win32gui.EnumWindows(enum_windows_callback, windows)

    if len(windows) == 0:
        raise Exception(f"No windows found with title starting with '{window_title_prefix}'")

    hwnd, title = windows[0]
    left, top, right, bottom = win32gui.GetWindowRect(hwnd)
    print(f"Window found: {title}, Rect: {left}, {top}, {right}, {bottom}")
    return {"left": left, "top": top, "width": right - left, "height": bottom - top}

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

def sift_template_matching(image, template):
    print("Starting SIFT template matching...")
    sift = cv2.SIFT_create()
    kp1, des1 = sift.detectAndCompute(template, None)
    kp2, des2 = sift.detectAndCompute(image, None)

    bf = cv2.BFMatcher()
    matches = bf.knnMatch(des1, des2, k=2)

    good_matches = []
    for m, n in matches:
        if m.distance < 0.75 * n.distance:
            good_matches.append(m)

    if len(good_matches) > 0:
        best_match = good_matches[0]
        pt_image = kp2[best_match.trainIdx].pt
        pt_template = kp1[best_match.queryIdx].pt
        exp_x = int(pt_image[0] - pt_template[0])
        exp_y = int(pt_image[1] - pt_template[1])
        print(f"Match found at: ({exp_x}, {exp_y})")
        return exp_x, exp_y
    else:
        raise Exception("No matches found using SIFT.")

def find_exp_and_extract_number(image):
    print("Finding EXP and extracting number...")
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    exp_x, exp_y = sift_template_matching(gray, template_exp)

    exp_w, exp_h = template_exp.shape[::-1]
    number_roi = image[exp_y - 5:exp_y + exp_h + 5, exp_x + exp_w:exp_x + exp_w + 200]

    gray_roi = cv2.cvtColor(number_roi, cv2.COLOR_BGR2GRAY)
    gray_roi = cv2.resize(gray_roi, None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC)
    _, thresh = cv2.threshold(gray_roi, 150, 255, cv2.THRESH_BINARY)

    custom_config = r'--oem 3 --psm 7 -c tessedit_char_whitelist="0123456789.[]%'
    extracted_text = pytesseract.image_to_string(thresh, config=custom_config)
    print(f"Extracted text: {extracted_text}")

    match = re.search(r"(\d+)[^\d]*(\d+\.\d+)%", extracted_text)
    if match:
        exp_value = match.group(1)
        exp_percentage = match.group(2)
        return f"{exp_value} [{exp_percentage}%]"
    else:
        raise Exception("Unable to parse EXP format.")
    
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
        level_value = match.group(0)
        return level_value
    else:
        raise Exception("Unable to parse level format.")

@app.route('/extract_exp_and_level', methods=['GET'])
def extract_exp_and_level():
    try:
        print("Starting to extract EXP and level data...")
        screenshot = capture_window_with_mss("MapleStory Worlds-Mapleland")
        exp_value = find_exp_and_extract_number(screenshot)  # ex: "966186 [88.84%]"
        level_value = find_lv_and_extract_level(screenshot)  # ex: "123"

        level_value = int(level_value)

        print(f"Extracted EXP: {exp_value}, Level: {level_value}")

        match = re.match(r"(\d+)\s\[(\d+\.\d+)%\]", exp_value)
        if match:
            exp = int(match.group(1))  # 966186
            percentage = float(match.group(2))  # 88.84
            return jsonify({"exp": exp, "percentage": percentage, "level": level_value})
        else:
            raise Exception("Invalid EXP format.")
    except Exception as e:
        print(f"Error: {str(e)}")
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000)
