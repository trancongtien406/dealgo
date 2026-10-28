import { describe, expect, it } from "vitest";
import {
  emailDraftFromView,
  emailPatch,
  emailTestErrorLabel,
  mapKeyTestLabel,
} from "@/features/integrations/mappers";
import type { EmailSettingsView } from "@/features/integrations/types";

const view: EmailSettingsView = {
  canStoreSecrets: true,
  secretsUnreadable: false,
  providers: ["smtp", "ses", "disabled"],
  provider: "smtp",
  fromName: "DealGo",
  fromAddress: "no-reply@dealgo.vn",
  smtp: { host: "smtp.gmail.com", port: 587, user: "ops@dealgo.vn", secure: false, passwordSet: true },
  ses: { region: "", configurationSet: "", snsTopicArn: "", accessKeyIdSet: false, secretAccessKeySet: false },
  sources: {
    provider: "admin",
    fromName: "default",
    fromAddress: "env",
    smtpHost: "default",
    smtpPort: "default",
    smtpUser: "env",
    smtpSecure: "default",
    sesRegion: "unset",
    sesConfigurationSet: "unset",
    sesSnsTopicArn: "unset",
    smtpPassword: "env",
    sesAccessKeyId: "unset",
    sesSecretAccessKey: "unset",
  },
  status: { configured: true, verified: false, testedAt: null },
  updatedAt: null,
  webhookPath: "/v1/webhooks/ses",
};

describe("emailPatch", () => {
  it("is empty when nothing changed", () => {
    expect(emailPatch(view, emailDraftFromView(view), {})).toEqual({});
  });

  it("sends changed fields, typed secrets and clears", () => {
    const draft = { ...emailDraftFromView(view), provider: "ses", sesRegion: " ap-southeast-1 ", fromName: "" };
    expect(
      emailPatch(view, draft, { sesAccessKeyId: "AKIA1", sesSecretAccessKey: "  ", smtpPassword: null }),
    ).toEqual({
      provider: "ses",
      sesRegion: "ap-southeast-1",
      fromName: null,
      sesAccessKeyId: "AKIA1",
      smtpPassword: null,
    });
  });

  it("maps mock provider to an empty draft value", () => {
    expect(emailDraftFromView({ ...view, provider: "mock" }).provider).toBe("");
  });
});

describe("labels", () => {
  it("translates known codes and passes unknown ones through", () => {
    expect(emailTestErrorLabel("auth_failed")).toMatch(/mật khẩu/);
    expect(emailTestErrorLabel("weird")).toBe("weird");
    expect(emailTestErrorLabel(null)).toBe("");
    expect(mapKeyTestLabel(true, "TokenValid")).toBe("Hoạt động");
    expect(mapKeyTestLabel(false, "REQUEST_DENIED")).toMatch(/Geocoding/);
  });
});
