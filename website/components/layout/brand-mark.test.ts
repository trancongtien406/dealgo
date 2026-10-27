import { describe, it, expect, vi } from "vitest";
import React from "react";
import { renderToString } from "react-dom/server";
import { BrandMark } from "./brand-mark";

describe("BrandMark", () => {
  it("renders without invalid DOM property warnings", () => {
    const errorSpy = vi.spyOn(console, "error").mockImplementation(() => {});

    const html = renderToString(React.createElement(BrandMark));

    expect(errorSpy).not.toHaveBeenCalled();
    expect(html).toContain('alt="DealGo"');
    expect(html).toContain("/dealgo-logo.svg");

    errorSpy.mockRestore();
  });

  it("uses the v3 icon for compact navigation", () => {
    const html = renderToString(
      React.createElement(BrandMark, { compact: true }),
    );

    expect(html).toContain('alt="DealGo"');
    expect(html).toContain("/dealgo-icon.svg");
  });
});
