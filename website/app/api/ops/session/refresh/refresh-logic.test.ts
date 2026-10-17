import { describe, expect, it } from "vitest";
import { escapeHtml, safeRelativeNext } from "./route";

describe("safeRelativeNext CSRF and XSS guard", () => {
  it("allows valid same-origin relative paths", () => {
    expect(safeRelativeNext("/overview")).toBe("/overview");
    expect(safeRelativeNext("/rides/12345")).toBe("/rides/12345");
    expect(safeRelativeNext("/settings/content?tab=privacy")).toBe(
      "/settings/content?tab=privacy",
    );
  });

  it("blocks protocol-relative URLs", () => {
    expect(safeRelativeNext("//evil.com")).toBe("/");
    expect(safeRelativeNext("//google.com/phishing")).toBe("/");
  });

  it("blocks absolute URLs with arbitrary protocols", () => {
    expect(safeRelativeNext("https://evil.com")).toBe("/");
    expect(safeRelativeNext("http://localhost:4000")).toBe("/");
    expect(safeRelativeNext("javascript:alert(1)")).toBe("/");
    expect(safeRelativeNext("data:text/html,evil")).toBe("/");
  });

  it("blocks HTML injection and XSS payloads", () => {
    expect(safeRelativeNext('/"><svg onload=alert(1)>')).toBe("/");
    expect(safeRelativeNext("/test' onfocus='alert(1)")).toBe("/");
    expect(safeRelativeNext("/<script>alert(1)</script>")).toBe("/");
    expect(safeRelativeNext("/`alert(1)`")).toBe("/");
    expect(safeRelativeNext("/path\r\nevil")).toBe("/");
  });

  it("blocks backslashes and null bytes", () => {
    expect(safeRelativeNext("/\\evil.com")).toBe("/");
    expect(safeRelativeNext("/path\0evil")).toBe("/");
  });

  it("falls back to root for null, empty or invalid strings", () => {
    expect(safeRelativeNext(null)).toBe("/");
    expect(safeRelativeNext("")).toBe("/");
    expect(safeRelativeNext("   ")).toBe("/");
    expect(safeRelativeNext("overview")).toBe("/");
  });
});

describe("escapeHtml utility", () => {
  it("escapes all HTML special characters", () => {
    expect(escapeHtml('<script>alert("XSS") & test\'</script>')).toBe(
      "&lt;script&gt;alert(&quot;XSS&quot;) &amp; test&#39;&lt;/script&gt;",
    );
  });
});
