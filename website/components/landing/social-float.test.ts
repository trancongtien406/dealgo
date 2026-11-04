import { describe, it, expect } from "vitest";
import React from "react";
import { renderToString } from "react-dom/server";
import SocialFloat from "./SocialFloat";
import type { PublicSiteConfig } from "@/features/site-config/types";

describe("SocialFloat", () => {
  it("renders null when siteConfig is undefined or has no socials", () => {
    expect(renderToString(React.createElement(SocialFloat))).toBe("");
    expect(renderToString(React.createElement(SocialFloat, { siteConfig: {} }))).toBe("");
    expect(renderToString(React.createElement(SocialFloat, { siteConfig: { socials: {} } }))).toBe("");
  });

  it("renders social links directly without a summary/details toggle trigger", () => {
    const config: PublicSiteConfig = {
      socials: {
        facebook: "https://facebook.com/dealgovn",
        zalo: "https://zalo.me/dealgo",
        tiktok: "https://tiktok.com/@dealgo",
      },
    };
    const html = renderToString(React.createElement(SocialFloat, { siteConfig: config }));

    // Must NOT have master toggle details/summary
    expect(html).not.toContain("<details");
    expect(html).not.toContain("<summary");
    expect(html).not.toContain("social-float-trigger");

    // Must directly render links for each configured social
    expect(html).toContain('href="https://facebook.com/dealgovn"');
    expect(html).toContain('href="https://zalo.me/dealgo"');
    expect(html).toContain('href="https://tiktok.com/@dealgo"');

    // Must NOT render unconfigured socials (e.g. youtube, messenger, instagram)
    expect(html).not.toContain("YouTube");
    expect(html).not.toContain("Instagram");
    expect(html).not.toContain("Messenger");

    // Tooltip or labels should be present
    expect(html).toContain("Facebook");
    expect(html).toContain("Zalo");
    expect(html).toContain("TikTok");

    // Button classes and animation styles
    expect(html).toContain("social-float-btn");
    expect(html).toContain("--social-float-index");

    // Safe external links
    expect(html).toContain('target="_blank"');
    expect(html).toContain('rel="noopener noreferrer me"');
  });
});
