import { describe, it, expect, vi } from "vitest";
import React from "react";
import { renderToString } from "react-dom/server";
import { BrandMark } from "./brand-mark";

describe("BrandMark", () => {
  it("renders without invalid DOM property warnings", () => {
    const errorSpy = vi.spyOn(console, "error").mockImplementation(() => {});

    const html = renderToString(React.createElement(BrandMark));

    expect(errorSpy).not.toHaveBeenCalled();
    expect(html).toContain("Deal");
    expect(html).toContain("Go");

    errorSpy.mockRestore();
  });
});
