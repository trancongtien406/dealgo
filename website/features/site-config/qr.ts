import QRCode from "qrcode";

/** Local SVG QR (no external QR service; CSP-safe). */
export async function qrSvg(text: string): Promise<string> {
  return QRCode.toString(text, { type: "svg", margin: 1, errorCorrectionLevel: "M", color: { dark: "#0F172A", light: "#FFFFFF" } });
}
