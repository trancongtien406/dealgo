import { describe, expect, it } from "vitest";
import { binaryFromOpsUpstream, parseByteRange } from "@/lib/api/ops-bff-response";

const clip = {
  ok: true as const,
  body: new Uint8Array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]).buffer,
  contentType: "video/mp4",
  disposition: 'inline; filename="selfie_video-5.mp4"',
};

describe("byte ranges for <video> (t54u, Safari)", () => {
  it("parses open, closed and suffix ranges", () => {
    expect(parseByteRange(null, 10)).toBeNull();
    expect(parseByteRange("bytes=0-1", 10)).toEqual([0, 1]);
    expect(parseByteRange("bytes=4-", 10)).toEqual([4, 9]);
    expect(parseByteRange("bytes=-3", 10)).toEqual([7, 9]);
    expect(parseByteRange("bytes=8-99", 10)).toEqual([8, 9]);
    expect(parseByteRange("bytes=10-", 10)).toBe("unsatisfiable");
    expect(parseByteRange("items=0-1", 10)).toBeNull();
  });

  it("answers Safari's bytes=0-1 probe with 206 + Content-Range", async () => {
    const res = binaryFromOpsUpstream(clip, "bytes=0-1");
    expect(res.status).toBe(206);
    expect(res.headers.get("content-type")).toBe("video/mp4");
    expect(res.headers.get("accept-ranges")).toBe("bytes");
    expect(res.headers.get("content-range")).toBe("bytes 0-1/10");
    expect(res.headers.get("content-length")).toBe("2");
    expect([...new Uint8Array(await res.arrayBuffer())]).toEqual([0, 1]);
  });

  it("serves the full body with Accept-Ranges, and 416 past the end", async () => {
    const full = binaryFromOpsUpstream(clip);
    expect(full.status).toBe(200);
    expect(full.headers.get("accept-ranges")).toBe("bytes");
    expect(full.headers.get("content-length")).toBe("10");
    const bad = binaryFromOpsUpstream(clip, "bytes=20-");
    expect(bad.status).toBe(416);
    expect(bad.headers.get("content-range")).toBe("bytes */10");
  });
});
