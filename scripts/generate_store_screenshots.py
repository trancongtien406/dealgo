#!/usr/bin/env python3
"""
Generate professional, high-conversion App Store & Google Play marketing screenshots for DealGo.
Inspired by top templates on appscreens.com (clean editorial white background, continuous panoramic
wave stage, high-contrast typography, realistic titanium device mockups, and 3D floating feature cards).

Supported Displays:
- iPhone 6.1" or 6.3" display: 1179 x 2556 px (App Store standard)
- iPhone 6.7" or 6.9" display: 1290 x 2796 px (App Store standard)
- iPad Pro 13" display: 2048 x 2732 px (App Store standard)
- Google Play Phone & Tablet
"""

import os
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
RAW_DIR_IPHONE = os.path.join(BASE_DIR, "screenshots", "raw", "iphone")
RAW_DIR_IPAD = os.path.join(BASE_DIR, "screenshots", "raw", "ipad")

OUT_APP_STORE_IPHONE_6_1 = os.path.join(BASE_DIR, "screenshots", "store_ready", "app_store", "iphone_6_1")
OUT_APP_STORE_IPHONE_6_7 = os.path.join(BASE_DIR, "screenshots", "store_ready", "app_store", "iphone_6_7")
OUT_APP_STORE_IPAD = os.path.join(BASE_DIR, "screenshots", "store_ready", "app_store", "ipad_13")
OUT_PLAY_PHONE = os.path.join(BASE_DIR, "screenshots", "store_ready", "google_play", "phone")
OUT_PLAY_TABLET = os.path.join(BASE_DIR, "screenshots", "store_ready", "google_play", "tablet")

FONT_BOLD = os.path.join(BASE_DIR, "mobile", "assets", "fonts", "BeVietnamPro-Bold.ttf")
FONT_EXTRA_BOLD = os.path.join(BASE_DIR, "mobile", "assets", "fonts", "BeVietnamPro-ExtraBold.ttf")
FONT_MEDIUM = os.path.join(BASE_DIR, "mobile", "assets", "fonts", "BeVietnamPro-Medium.ttf")
FONT_SEMI = os.path.join(BASE_DIR, "mobile", "assets", "fonts", "BeVietnamPro-SemiBold.ttf")

SHOT_CONFIGS = [
    {
        "id": "01_home_multiservice",
        "raw_file": "01_customer_home.png",
        "badge": "✨ DEALGO ALL-IN-ONE",
        "title_l1": "Mở DealGo, Có Mọi Điều",
        "title_l2": "Bạn Cần Ngay",
        "sub": "Đặt xe, gọi món đặc sản & giao hàng hỏa tốc trong 1 chạm",
        "accent_color": (0, 168, 107),      # DealGo Emerald
        "stage_bg": (240, 253, 244),        # Light Mint
        "stage_border": (187, 247, 208),
        "card1": {"side": "left", "y_pct": 0.32, "icon": "percent", "icon_color": (245, 158, 11), "tag": "Ưu đãi bạn mới", "val": "Giảm 50% Chuyến Đầu"},
        "card2": {"side": "right", "y_pct": 0.77, "icon": "bolt", "icon_color": (16, 185, 129), "tag": "Tiện ích đa dạng", "val": "Xe máy, Ô tô & Đồ ăn"}
    },
    {
        "id": "02_ride_booking",
        "raw_file": "02_ride_booking.png",
        "badge": "🚗 ĐẶT XE CÔNG NGHỆ",
        "title_l1": "Đặt Xe Siêu Tốc,",
        "title_l2": "Giá Cực Rõ Ràng",
        "sub": "Đa dạng xe máy, 4 chỗ & 7 chỗ với cước phí minh bạch từng mét",
        "accent_color": (2, 132, 199),      # Sky Blue
        "stage_bg": (240, 249, 255),        # Light Sky
        "stage_border": (186, 230, 253),
        "card1": {"side": "right", "y_pct": 0.33, "icon": "bolt", "icon_color": (2, 132, 199), "tag": "Đón nhanh tức thì", "val": "⚡ Tài xế tới sau 2P"},
        "card2": {"side": "left", "y_pct": 0.78, "icon": "check", "icon_color": (16, 185, 129), "tag": "Đội xe chất lượng", "val": "Xe máy & Ô tô 4-7 chỗ"}
    },
    {
        "id": "03_food_discovery",
        "raw_file": "03_food_discovery.png",
        "badge": "🍜 DEALGO FOOD",
        "title_l1": "Món Ngon Quanh Bạn,",
        "title_l2": "Giao Nhanh Tận Cửa",
        "sub": "Hàng ngàn quán ngon đặc sản, menu phong phú giảm giá mỗi ngày",
        "accent_color": (234, 88, 12),      # Orange
        "stage_bg": (255, 247, 237),        # Light Orange
        "stage_border": (254, 215, 170),
        "card1": {"side": "left", "y_pct": 0.31, "icon": "percent", "icon_color": (234, 88, 12), "tag": "Ưu đãi ẩm thực", "val": "Freeship Đơn Từ 0Đ"},
        "card2": {"side": "right", "y_pct": 0.78, "icon": "star", "icon_color": (245, 158, 11), "tag": "Quán hot chọn lọc", "val": "Giao nóng trong 20P"}
    },
    {
        "id": "04_food_store",
        "raw_file": "04_food_store.png",
        "badge": "⭐ QUÁN NGON CHỌN LỌC",
        "title_l1": "Menu Phong Phú,",
        "title_l2": "Chọn Topping Dễ Dàng",
        "sub": "Tự do tùy biến khẩu vị, giá niêm yết rõ ràng không phụ phí ẩn",
        "accent_color": (225, 29, 72),      # Rose Red
        "stage_bg": (255, 241, 242),        # Light Rose
        "stage_border": (254, 205, 211),
        "card1": {"side": "right", "y_pct": 0.32, "icon": "star", "icon_color": (245, 158, 11), "tag": "Đánh giá thực tế", "val": "4.9 ★ (1.800+ đã bán)"},
        "card2": {"side": "left", "y_pct": 0.77, "icon": "check", "icon_color": (225, 29, 72), "tag": "Chất lượng cam kết", "val": "100% Nguyên liệu tươi"}
    },
    {
        "id": "05_order_tracking",
        "raw_file": "05_order_tracking.png",
        "badge": "📍 THEO DÕI LIVE GPS",
        "title_l1": "Hành Trình Trực Tiếp,",
        "title_l2": "Shipper Đang Đến",
        "sub": "Bản đồ trực quan từng mét, an tâm tận hưởng món ngon đúng hẹn",
        "accent_color": (124, 58, 237),     # Purple
        "stage_bg": (245, 243, 255),        # Light Purple
        "stage_border": (221, 214, 254),
        "card1": {"side": "left", "y_pct": 0.33, "icon": "pin", "icon_color": (124, 58, 237), "tag": "Định vị GPS chuẩn", "val": "Cập nhật thời gian thực"},
        "card2": {"side": "right", "y_pct": 0.76, "icon": "bolt", "icon_color": (16, 185, 129), "tag": "Dự kiến chính xác", "val": "Đến nơi sau ≈ 4 phút"}
    },
    {
        "id": "06_driver_jobs",
        "raw_file": "06_driver_jobs.png",
        "badge": "💼 ĐỐI TÁC TÀI XẾ DEALGO",
        "title_l1": "Bật App Nhận Cuốc,",
        "title_l2": "Thu Nhập Vững Vàng",
        "sub": "Chủ động thời gian, nhận cuốc liên tục và rút tiền linh hoạt trong ngày",
        "accent_color": (5, 150, 105),      # Emerald Green
        "stage_bg": (236, 253, 245),        # Light Emerald
        "stage_border": (167, 243, 208),
        "card1": {"side": "right", "y_pct": 0.32, "icon": "check", "icon_color": (5, 150, 105), "tag": "Thu nhập minh bạch", "val": "+28.000đ Cuốc hoàn tất"},
        "card2": {"side": "left", "y_pct": 0.77, "icon": "star", "icon_color": (245, 158, 11), "tag": "Cộng đồng đối tác", "val": "Bảo hiểm chuyến đi 100%"}
    }
]


def draw_pill(draw, x, y, text, font, bg_color, text_color, border_color=None):
    bbox = font.getbbox(text)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    px, py = 26, 12
    w = tw + px * 2
    h = th + py * 2
    rect = [x - w // 2, y, x + w // 2, y + h]
    draw.rounded_rectangle(rect, radius=h // 2, fill=bg_color, outline=border_color, width=2 if border_color else 0)
    tx = x - tw // 2
    ty = y + (h - th) // 2 - bbox[1]
    draw.text((tx, ty), text, font=font, fill=text_color)
    return y + h


def draw_floating_card(canvas, x, y, icon_type, tag_text, title_text, accent_color, scale=1.0, font_tag=None, font_title=None):
    cw = int(480 * scale)
    ch = int(136 * scale)
    card_layer = Image.new('RGBA', (cw + 60, ch + 60), (0, 0, 0, 0))
    cdraw = ImageDraw.Draw(card_layer)
    
    # Soft drop shadow
    shadow_rect = [30, 30 + int(8 * scale), 30 + cw, 30 + ch + int(8 * scale)]
    cdraw.rounded_rectangle(shadow_rect, radius=int(26 * scale), fill=(15, 23, 42, 38))
    card_layer = card_layer.filter(ImageFilter.GaussianBlur(int(14 * scale)))
    cdraw = ImageDraw.Draw(card_layer)
    
    # Card surface: Crisp white with subtle border
    card_rect = [30, 30, 30 + cw, 30 + ch]
    cdraw.rounded_rectangle(card_rect, radius=int(26 * scale), fill=(255, 255, 255, 255), outline=(226, 232, 240, 255), width=2)
    
    # Left circular icon
    icon_cx = 30 + int(50 * scale)
    icon_cy = 30 + ch // 2
    r = int(32 * scale)
    cdraw.ellipse([icon_cx - r, icon_cy - r, icon_cx + r, icon_cy + r], fill=accent_color)
    
    # Vector icon inside circle
    if icon_type == 'star':
        pts = []
        for i in range(10):
            rad = math.pi / 2 + i * math.pi / 5
            cur_r = int(18 * scale) if i % 2 == 0 else int(8 * scale)
            pts.append((icon_cx + cur_r * math.cos(rad), icon_cy - cur_r * math.sin(rad)))
        cdraw.polygon(pts, fill=(255, 255, 255, 255))
    elif icon_type == 'percent':
        pts = [
            (icon_cx - int(10 * scale), icon_cy + int(10 * scale)),
            (icon_cx + int(10 * scale), icon_cy - int(10 * scale))
        ]
        cdraw.line(pts, fill=(255, 255, 255, 255), width=int(3 * scale))
        cdraw.ellipse([icon_cx - int(10 * scale), icon_cy - int(10 * scale), icon_cx - int(4 * scale), icon_cy - int(4 * scale)], fill=(255, 255, 255, 255))
        cdraw.ellipse([icon_cx + int(4 * scale), icon_cy + int(4 * scale), icon_cx + int(10 * scale), icon_cy + int(10 * scale)], fill=(255, 255, 255, 255))
    elif icon_type == 'bolt':
        pts = [
            (icon_cx + int(2 * scale), icon_cy - int(18 * scale)),
            (icon_cx - int(12 * scale), icon_cy + int(2 * scale)),
            (icon_cx, icon_cy + int(2 * scale)),
            (icon_cx - int(4 * scale), icon_cy + int(18 * scale)),
            (icon_cx + int(12 * scale), icon_cy - int(2 * scale)),
            (icon_cx, icon_cy - int(2 * scale))
        ]
        cdraw.polygon(pts, fill=(255, 255, 255, 255))
    elif icon_type == 'check':
        pts = [
            (icon_cx - int(12 * scale), icon_cy),
            (icon_cx - int(4 * scale), icon_cy + int(8 * scale)),
            (icon_cx + int(12 * scale), icon_cy - int(10 * scale))
        ]
        cdraw.line(pts, fill=(255, 255, 255, 255), width=int(4 * scale))
    elif icon_type == 'pin':
        cdraw.ellipse([icon_cx - int(13 * scale), icon_cy - int(15 * scale), icon_cx + int(13 * scale), icon_cy + int(11 * scale)], fill=(255, 255, 255, 255))
        cdraw.polygon([(icon_cx - int(9 * scale), icon_cy - int(1 * scale)), (icon_cx + int(9 * scale), icon_cy - int(1 * scale)), (icon_cx, icon_cy + int(16 * scale))], fill=(255, 255, 255, 255))
        cdraw.ellipse([icon_cx - int(5 * scale), icon_cy - int(4 * scale), icon_cx + int(5 * scale), icon_cy + int(6 * scale)], fill=accent_color)
    else:
        cdraw.ellipse([icon_cx - int(10 * scale), icon_cy - int(10 * scale), icon_cx + int(10 * scale), icon_cy + int(10 * scale)], fill=(255, 255, 255, 255))
        
    # Text
    tx = icon_cx + r + int(20 * scale)
    ty1 = 30 + int(32 * scale)
    cdraw.text((tx, ty1), tag_text.upper(), font=font_tag, fill=(100, 116, 139, 255))
    ty2 = ty1 + int(32 * scale)
    cdraw.text((tx, ty2), title_text, font=font_title, fill=(15, 23, 42, 255))
    
    canvas.paste(card_layer, (x - 30, y - 30), card_layer)


def get_wave_y(slide_idx, x, width, height, total_slides=6):
    """
    Mathematical continuous wave connecting slide 0 to 5 seamlessly across the entire gallery.
    """
    t = (slide_idx * width + x) / (total_slides * width)
    base_y = height * 0.22
    amp = height * 0.03
    return base_y + amp * math.sin(2 * math.pi * t * 1.5) + (amp * 0.5) * math.cos(2 * math.pi * t * 3.0)


def render_store_screenshot(cfg, slide_idx, device_type="iphone_6_1"):
    """
    Render screenshot for specific device specifications:
    - iphone_6_1: 1179 x 2556 px (Apple iPhone 6.1" or 6.3" displays)
    - iphone_6_7: 1290 x 2796 px (Apple iPhone 6.7" or 6.9" displays)
    - ipad_13:    2048 x 2732 px (Apple iPad Pro 13" displays)
    """
    if device_type == "ipad_13":
        W, H = 2048, 2732
        scale = 1.2
        target_sw, target_sh = 1460, 1980
        phone_y = 660
        bezel_radius = 64
        border = 20
        tag_f = ImageFont.truetype(FONT_BOLD, 30)
        title_f = ImageFont.truetype(FONT_BOLD, 72)
        sub_f = ImageFont.truetype(FONT_MEDIUM, 36)
        card_tag_f = ImageFont.truetype(FONT_MEDIUM, 26)
        card_val_f = ImageFont.truetype(FONT_BOLD, 34)
        raw_path = os.path.join(RAW_DIR_IPAD, cfg["raw_file"])
        has_dynamic_island = False
    elif device_type == "iphone_6_1":
        # Apple standard for iPhone 6.1" or 6.3" display: 1179 x 2556 px
        W, H = 1179, 2556
        scale = 1179.0 / 1290.0  # ~0.914
        target_sw, target_sh = int(940 * scale), int(2040 * scale)
        phone_y = int(620 * scale)
        bezel_radius = int(78 * scale)
        border = int(18 * scale)
        tag_f = ImageFont.truetype(FONT_BOLD, int(26 * scale))
        title_f = ImageFont.truetype(FONT_BOLD, int(64 * scale))
        sub_f = ImageFont.truetype(FONT_MEDIUM, int(32 * scale))
        card_tag_f = ImageFont.truetype(FONT_MEDIUM, int(22 * scale))
        card_val_f = ImageFont.truetype(FONT_BOLD, int(30 * scale))
        raw_path = os.path.join(RAW_DIR_IPHONE, cfg["raw_file"])
        has_dynamic_island = True
    else:  # iphone_6_7
        # Apple standard for iPhone 6.7" or 6.9" display: 1290 x 2796 px
        W, H = 1290, 2796
        scale = 1.0
        target_sw, target_sh = 940, 2040
        phone_y = 620
        bezel_radius = 78
        border = 18
        tag_f = ImageFont.truetype(FONT_BOLD, 26)
        title_f = ImageFont.truetype(FONT_BOLD, 64)
        sub_f = ImageFont.truetype(FONT_MEDIUM, 32)
        card_tag_f = ImageFont.truetype(FONT_MEDIUM, 22)
        card_val_f = ImageFont.truetype(FONT_BOLD, 30)
        raw_path = os.path.join(RAW_DIR_IPHONE, cfg["raw_file"])
        has_dynamic_island = True

    # 1. Base clean white canvas
    canvas = Image.new('RGB', (W, H), '#FFFFFF')
    draw = ImageDraw.Draw(canvas)
    
    # 2. Subtle dot grid in top corners
    dot_color = (241, 245, 249)
    step = int(40 * scale)
    grid_h = int(400 * scale)
    corner_w = int(240 * scale)
    for x in range(int(50 * scale), W - int(50 * scale), step):
        for y in range(int(40 * scale), grid_h, step):
            if (x < corner_w or x > W - corner_w) and y < grid_h - int(30 * scale):
                draw.ellipse([x-2, y-2, x+2, y+2], fill=dot_color)

    # 3. Continuous Panoramic Wave Stage
    wave_layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    w_draw = ImageDraw.Draw(wave_layer)
    points = [(0, H)]
    num_pts = 40
    for i in range(num_pts + 1):
        x = i * (W / num_pts)
        y = get_wave_y(slide_idx, x, W, H)
        points.append((x, y))
    points.append((W, H))
    
    w_draw.polygon(points, fill=(*cfg["stage_bg"], 255))
    border_pts = points[1:-1]
    for i in range(len(border_pts) - 1):
        w_draw.line([border_pts[i], border_pts[i+1]], fill=(*cfg["stage_border"], 255), width=int(3 * scale))
    canvas.paste(wave_layer, (0, 0), wave_layer)
    
    # 4. Editorial Typography Header
    cur_y = int(105 * scale)
    cur_y = draw_pill(draw, W // 2, cur_y, cfg["badge"], tag_f, (241, 245, 249), (71, 85, 105), (226, 232, 240))
    
    cur_y += int(34 * scale)
    bbox1 = title_f.getbbox(cfg["title_l1"])
    draw.text((W // 2 - (bbox1[2]-bbox1[0]) // 2, cur_y), cfg["title_l1"], font=title_f, fill=(15, 23, 42))
    cur_y += (bbox1[3] - bbox1[1]) + int(16 * scale)
    
    bbox2 = title_f.getbbox(cfg["title_l2"])
    draw.text((W // 2 - (bbox2[2]-bbox2[0]) // 2, cur_y), cfg["title_l2"], font=title_f, fill=cfg["accent_color"])
    cur_y += (bbox2[3] - bbox2[1]) + int(24 * scale)
    
    sub_bbox = sub_f.getbbox(cfg["sub"])
    draw.text((W // 2 - (sub_bbox[2]-sub_bbox[0]) // 2, cur_y), cfg["sub"], font=sub_f, fill=(100, 116, 139))
    
    # 5. Device Mockup
    if not os.path.exists(raw_path):
        raise FileNotFoundError(f"Missing raw screenshot: {raw_path}")
    raw_shot = Image.open(raw_path).convert('RGBA')
    screen_resized = raw_shot.resize((target_sw, target_sh), Image.Resampling.LANCZOS)
    
    screen_mask = Image.new('L', (target_sw, target_sh), 0)
    smdraw = ImageDraw.Draw(screen_mask)
    smdraw.rounded_rectangle([0, 0, target_sw, target_sh], radius=int(60 * scale), fill=255)
    
    fw, fh = target_sw + border * 2, target_sh + border * 2
    frame_layer = Image.new('RGBA', (fw + 80, fh + 80), (0, 0, 0, 0))
    fdraw = ImageDraw.Draw(frame_layer)
    
    # Realistic soft ground contact shadow
    shadow_rect = [40, 40 + int(18 * scale), 40 + fw, 40 + fh + int(18 * scale)]
    fdraw.rounded_rectangle(shadow_rect, radius=bezel_radius, fill=(15, 23, 42, 45))
    frame_layer = frame_layer.filter(ImageFilter.GaussianBlur(int(26 * scale)))
    fdraw = ImageDraw.Draw(frame_layer)
    
    # Titanium Bezel Outer
    bezel_rect = [40, 40, 40 + fw, 40 + fh]
    fdraw.rounded_rectangle(bezel_rect, radius=bezel_radius, fill=(30, 41, 59, 255), outline=(71, 85, 105, 255), width=2)
    
    # Screen placement
    screen_rect = [40 + border, 40 + border]
    frame_layer.paste(screen_resized, screen_rect, screen_mask)
    
    # Dynamic Island (for iPhone only)
    if has_dynamic_island:
        di_w, di_h = int(240 * scale), int(68 * scale)
        di_x = 40 + border + (target_sw - di_w) // 2
        di_y = 40 + border + int(24 * scale)
        fdraw.rounded_rectangle([di_x, di_y, di_x + di_w, di_y + di_h], radius=di_h // 2, fill=(0, 0, 0, 255))
    
    phone_x = (W - fw) // 2
    canvas.paste(frame_layer, (phone_x - 40, phone_y - 40), frame_layer)
    
    # 6. Floating Cards
    cw = int(480 * scale)
    c1 = cfg["card1"]
    c1_x = int(46 * scale) if c1["side"] == "left" else (W - int(46 * scale) - cw)
    c1_y = int(H * c1["y_pct"])
    draw_floating_card(canvas, c1_x, c1_y, c1["icon"], c1["tag"], c1["val"], c1["icon_color"], scale, card_tag_f, card_val_f)
    
    c2 = cfg["card2"]
    c2_x = int(46 * scale) if c2["side"] == "left" else (W - int(46 * scale) - cw)
    c2_y = int(H * c2["y_pct"])
    draw_floating_card(canvas, c2_x, c2_y, c2["icon"], c2["tag"], c2["val"], c2["icon_color"], scale, card_tag_f, card_val_f)
    
    return canvas


def main():
    os.makedirs(OUT_APP_STORE_IPHONE_6_1, exist_ok=True)
    os.makedirs(OUT_APP_STORE_IPHONE_6_7, exist_ok=True)
    os.makedirs(OUT_APP_STORE_IPAD, exist_ok=True)
    os.makedirs(OUT_PLAY_PHONE, exist_ok=True)
    os.makedirs(OUT_PLAY_TABLET, exist_ok=True)
    
    print("🎨 Generating App Store & Google Play marketing screenshots...")
    
    for idx, cfg in enumerate(SHOT_CONFIGS):
        fn = f"{idx+1:02d}_{cfg['id']}.png"
        print(f"\n[{idx+1}/6] Processing: {cfg['badge']} - {cfg['title_l1']} {cfg['title_l2']}")
        
        # 1. iPhone 6.1" or 6.3" display: 1179 x 2556 px (Apple App Store standard)
        iphone_6_1_img = render_store_screenshot(cfg, idx, device_type="iphone_6_1")
        out_iphone_6_1 = os.path.join(OUT_APP_STORE_IPHONE_6_1, fn)
        iphone_6_1_img.save(out_iphone_6_1, optimize=True)
        print(f"  ✓ App Store iPhone 6.1\" (1179x2556): {out_iphone_6_1}")

        # 2. iPhone 6.7" or 6.9" display: 1290 x 2796 px (Apple App Store standard)
        iphone_6_7_img = render_store_screenshot(cfg, idx, device_type="iphone_6_7")
        out_iphone_6_7 = os.path.join(OUT_APP_STORE_IPHONE_6_7, fn)
        out_play_phone = os.path.join(OUT_PLAY_PHONE, fn)
        iphone_6_7_img.save(out_iphone_6_7, optimize=True)
        iphone_6_7_img.save(out_play_phone, optimize=True)
        print(f"  ✓ App Store iPhone 6.7\" & Play Store Phone (1290x2796): {out_iphone_6_7}")
        
        # 3. iPad Pro 13" display: 2048 x 2732 px (Apple App Store standard)
        ipad_img = render_store_screenshot(cfg, idx, device_type="ipad_13")
        out_ipad = os.path.join(OUT_APP_STORE_IPAD, fn)
        out_play_tablet = os.path.join(OUT_PLAY_TABLET, fn)
        ipad_img.save(out_ipad, optimize=True)
        ipad_img.save(out_play_tablet, optimize=True)
        print(f"  ✓ App Store iPad & Play Store Tablet (2048x2732): {out_ipad}")

    print("\n🎉 All store screenshots generated successfully!")


if __name__ == "__main__":
    main()
