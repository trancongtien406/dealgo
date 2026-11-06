import os
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
FONT_BOLD = os.path.join(BASE_DIR, "mobile", "assets", "fonts", "BeVietnamPro-Bold.ttf")
FONT_EXTRA_BOLD = os.path.join(BASE_DIR, "mobile", "assets", "fonts", "BeVietnamPro-ExtraBold.ttf")
FONT_MEDIUM = os.path.join(BASE_DIR, "mobile", "assets", "fonts", "BeVietnamPro-Medium.ttf")
FONT_SEMI = os.path.join(BASE_DIR, "mobile", "assets", "fonts", "BeVietnamPro-SemiBold.ttf")

def draw_star(draw, cx, cy, r_outer, r_inner, fill):
    points = []
    for i in range(10):
        r = r_outer if i % 2 == 0 else r_inner
        angle = i * math.pi / 5 - math.pi / 2
        points.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
    draw.polygon(points, fill=fill)

def draw_floating_badge(canvas, x, y, icon_type, text, subtext=None, accent_color=(16, 185, 129)):
    font_main = ImageFont.truetype(FONT_BOLD, 28)
    font_sub = ImageFont.truetype(FONT_MEDIUM, 20)
    font_badge_icon = ImageFont.truetype(FONT_BOLD, 22)
    
    pad_h = 24
    pad_v = 16
    icon_box_size = 46
    
    b_main = font_main.getbbox(text)
    w_main = b_main[2] - b_main[0]
    h_main = b_main[3] - b_main[1]
    
    w_sub, h_sub = 0, 0
    if subtext:
        b_sub = font_sub.getbbox(subtext)
        w_sub = b_sub[2] - b_sub[0]
        h_sub = b_sub[3] - b_sub[1]
        
    content_w = max(w_main, w_sub)
    card_w = pad_h * 2 + icon_box_size + 16 + content_w
    card_h = pad_v * 2 + max(icon_box_size, h_main + (h_sub + 6 if subtext else 0))
    
    card_img = Image.new("RGBA", (card_w + 60, card_h + 60), (0, 0, 0, 0))
    c_draw = ImageDraw.Draw(card_img)
    
    # 1. 3D Floating Drop Shadow
    c_draw.rounded_rectangle(
        [(30, 36), (30 + card_w, 36 + card_h)],
        radius=26,
        fill=(0, 0, 0, 110)
    )
    card_img = card_img.filter(ImageFilter.GaussianBlur(radius=16))
    
    # 2. Translucent Glass Card Body
    card_body = Image.new("RGBA", (card_w + 60, card_h + 60), (0, 0, 0, 0))
    b_draw = ImageDraw.Draw(card_body)
    b_draw.rounded_rectangle(
        [(30, 30), (30 + card_w, 30 + card_h)],
        radius=24,
        fill=(255, 255, 255, 248),
        outline=(255, 255, 255, 255),
        width=2
    )
    
    # 3. Colorful Icon Badge Circle
    ix0 = 30 + pad_h
    iy0 = 30 + (card_h - icon_box_size) // 2
    ix1 = ix0 + icon_box_size
    iy1 = iy0 + icon_box_size
    
    # Soft background circle with 15% tint
    b_draw.rounded_rectangle([(ix0, iy0), (ix1, iy1)], radius=14, 
                             fill=(accent_color[0], accent_color[1], accent_color[2], 35))
                             
    icx = (ix0 + ix1) // 2
    icy = (iy0 + iy1) // 2
    if icon_type == "star":
        draw_star(b_draw, icx, icy, 14, 7, fill=accent_color)
    elif icon_type == "percent":
        b_draw.text((icx - 9, icy - 13), "%", font=font_badge_icon, fill=accent_color)
    elif icon_type == "bolt":
        # Draw lightning bolt polygon
        pts = [(icx + 1, icy - 13), (icx - 8, icy + 1), (icx - 1, icy + 1), (icx - 3, icy + 13), (icx + 8, icy - 2), (icx + 1, icy - 2)]
        b_draw.polygon(pts, fill=accent_color)
    elif icon_type == "check":
        # Draw checkmark
        b_draw.line([(icx - 8, icy), (icx - 2, icy + 6), (icx + 8, icy - 6)], fill=accent_color, width=3)
    elif icon_type == "pin":
        b_draw.ellipse([(icx - 6, icy - 10), (icx + 6, icy + 2)], fill=accent_color)
        pts = [(icx - 6, icy - 4), (icx + 6, icy - 4), (icx, icy + 10)]
        b_draw.polygon(pts, fill=accent_color)
        b_draw.ellipse([(icx - 2, icy - 6), (icx + 2, icy - 2)], fill=(255, 255, 255, 255))
    else:
        b_draw.text((icx - 8, icy - 13), "★", font=font_badge_icon, fill=accent_color)
        
    # Text
    tx = ix1 + 16
    ty_main = 30 + pad_v
    b_draw.text((tx, ty_main), text, font=font_main, fill=(15, 23, 42, 255))
    if subtext:
        b_draw.text((tx, ty_main + h_main + 6), subtext, font=font_sub, fill=(100, 116, 139, 255))
        
    final_card = Image.alpha_composite(card_img, card_body)
    canvas.paste(final_card, (x - 30, y - 30), final_card)

print("Vector badges tested successfully")
