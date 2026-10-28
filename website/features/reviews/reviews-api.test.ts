import { describe, expect, it } from "vitest";
import { mapReview, reviewsSearch } from "./api";

describe("reviews api", () => {
  it("builds only meaningful search params", () => {
    const search = reviewsSearch({
      page: 2,
      limit: 10,
      q: "  nguội ",
      visibility: "HIDDEN",
      maxStars: "2",
      storeId: "",
    });
    expect(search.toString()).toBe("page=2&limit=10&q=ngu%E1%BB%99i&visibility=HIDDEN&maxStars=2");
  });

  it("drops invalid visibility and star filters", () => {
    const search = reviewsSearch({ page: 1, limit: 10, visibility: "ALL", maxStars: "9" });
    expect(search.has("visibility")).toBe(false);
    expect(search.has("maxStars")).toBe(false);
  });

  it("maps a raw row with safe defaults", () => {
    const review = mapReview({ id: "r1", stars: 7, comment: "  ", merchantReply: null });
    expect(review).toMatchObject({
      id: "r1",
      stars: 5,
      comment: null,
      merchantReply: null,
      storeName: "Cửa hàng",
      tags: [],
      hidden: false,
    });
  });
});
