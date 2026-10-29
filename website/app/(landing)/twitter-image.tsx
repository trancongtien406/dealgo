import { ImageResponse } from "next/og";

export const alt = "DealGo – Đặt xe thương lượng giá và đặt đồ ăn tại Đà Nẵng";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default function OpengraphImage() {
  return new ImageResponse(
    <div
      style={{
        width: "100%",
        height: "100%",
        display: "flex",
        flexDirection: "column",
        justifyContent: "center",
        padding: 80,
        background: "#F8F7FF",
        fontFamily: "sans-serif",
      }}
    >
      <div style={{ display: "flex", fontSize: 120, fontWeight: 900 }}>
        <span style={{ color: "#6D28D9" }}>Deal</span>
        <span style={{ color: "#00D06C" }}>Go</span>
      </div>
      <div style={{ fontSize: 44, color: "#0F172A", marginTop: 24 }}>
        Ride booking with price negotiation · Food delivery
      </div>
      <div style={{ fontSize: 34, color: "#64748B", marginTop: 16 }}>
        Da Nang
      </div>
    </div>,
    size,
  );
}
