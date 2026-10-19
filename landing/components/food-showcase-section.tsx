"use client";

import { useState } from "react";
import Image from "next/image";

export function FoodShowcaseSection() {
  const [activeCategory, setActiveCategory] = useState("all");

  const categories = [
    { id: "all", label: "Tất cả món ngon" },
    { id: "noodles", label: "Bún & Mì Quảng" },
    { id: "bread", label: "Bánh mì & Ăn sáng" },
    { id: "drinks", label: "Trà sữa & Cà phê" },
  ];

  const foods = [
    {
      id: "banh-mi",
      category: "bread",
      name: "Bánh Mì Pate Chả Giòn Rụm",
      store: "Bánh Mì Cô Lan • Hải Châu",
      price: 25000,
      oldPrice: 30000,
      rating: "4.9",
      deliveryTime: "15 phút",
      image: "/assets/images/food_banh_mi.png",
      tag: "Bán chạy #1",
      tagColor: "bg-orange-500/10 text-orange-600 dark:text-orange-400 border border-orange-500/20",
    },
    {
      id: "mi-quang",
      category: "noodles",
      name: "Mì Quảng Ếch & Tôm Thịt Truyền Thống",
      store: "Mì Quảng Bếp Trang • Đà Nẵng",
      price: 45000,
      oldPrice: 55000,
      rating: "4.9",
      deliveryTime: "20 phút",
      image: "/assets/images/food_mi_quang.png",
      tag: "Đặc sản Đà Nẵng",
      tagColor: "bg-purple-500/10 text-purple-600 dark:text-purple-400 border border-purple-500/20",
    },
    {
      id: "bun-bo",
      category: "noodles",
      name: "Bún Bò Huế Thố Đá Đặc Biệt",
      store: "Bún Bò O Cương • Ngũ Hành Sơn",
      price: 52000,
      oldPrice: 60000,
      rating: "4.8",
      deliveryTime: "18 phút",
      image: "/assets/images/food_bun_bo_special.png",
      tag: "Nóng sốt tận cửa",
      tagColor: "bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border border-emerald-500/20",
    },
    {
      id: "tra-sua",
      category: "drinks",
      name: "Trà Sữa Ô Long Nướng Trân Châu Hoàng Kim",
      store: "Toco Toco • Sơn Trà",
      price: 32000,
      oldPrice: 42000,
      rating: "4.9",
      deliveryTime: "12 phút",
      image: "/assets/images/food_tra_sua.png",
      tag: "Giảm 25%",
      tagColor: "bg-rose-500/10 text-rose-600 dark:text-rose-400 border border-rose-500/20",
    },
  ];

  const filteredFoods =
    activeCategory === "all"
      ? foods
      : foods.filter((f) => f.category === activeCategory);

  return (
    <section className="py-20 sm:py-28 bg-[var(--color-canvas)] border-t border-[var(--color-border)]">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="flex flex-col items-center justify-between gap-6 md:flex-row md:items-end">
          <div className="max-w-xl text-center md:text-left">
            <span className="inline-flex items-center gap-1.5 rounded-full bg-orange-500/10 px-3.5 py-1 text-xs font-bold text-orange-600 dark:text-orange-400">
              <span>🍲</span>
              <span>Ẩm thực bốn phương cùng DealGo Food</span>
            </span>
            <h2 className="mt-3 text-3xl font-extrabold tracking-tight text-[var(--color-ink)] sm:text-4xl">
              Hàng ngàn món ngon nóng hổi, giao tận tay trong 20 phút
            </h2>
            <p className="mt-3 text-sm text-[var(--color-muted)]">
              Từ bánh mì giòn tan cho bữa sáng vội, đến tô mì Quảng đậm đà hay ly trà sữa giải nhiệt giờ xế chiều.
            </p>
          </div>

          {/* Category Filter Pills */}
          <div className="flex flex-wrap justify-center gap-2">
            {categories.map((cat) => (
              <button
                key={cat.id}
                onClick={() => setActiveCategory(cat.id)}
                className={`rounded-xl px-4 py-2 text-xs font-bold transition-all ${
                  activeCategory === cat.id
                    ? "bg-[var(--color-food)] text-white shadow-md shadow-orange-600/25"
                    : "border border-[var(--color-border)] bg-[var(--color-canvas-card)] text-[var(--color-muted)] hover:text-[var(--color-ink)] hover:border-slate-300 dark:hover:border-slate-700"
                }`}
              >
                {cat.label}
              </button>
            ))}
          </div>
        </div>

        {/* Food Cards Grid with Real PNG Images */}
        <div className="mt-12 grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
          {filteredFoods.map((item) => (
            <div
              key={item.id}
              className="glass-card group flex flex-col justify-between overflow-hidden rounded-3xl border border-[var(--color-border)] bg-[var(--color-canvas-card)] shadow-xs transition-all hover:shadow-xl hover:border-orange-500/40"
            >
              <div>
                {/* Real Food Image Container */}
                <div className="relative aspect-[4/3] w-full overflow-hidden bg-slate-100 dark:bg-slate-900">
                  <img
                    src={item.image}
                    alt={item.name}
                    className="h-full w-full object-cover transition-transform duration-500 group-hover:scale-108"
                  />
                  <div className="absolute top-3 left-3">
                    <span className={`rounded-full px-2.5 py-0.8 text-[11px] font-bold shadow-xs backdrop-blur-md ${item.tagColor}`}>
                      {item.tag}
                    </span>
                  </div>
                  <div className="absolute bottom-3 right-3 flex items-center gap-1 rounded-full bg-black/60 px-2 py-0.5 text-[10px] font-semibold text-white backdrop-blur-xs">
                    <span>⚡</span>
                    <span>{item.deliveryTime}</span>
                  </div>
                </div>

                {/* Details */}
                <div className="p-5">
                  <p className="text-[10px] font-semibold text-[var(--color-muted)]">{item.store}</p>
                  <h3 className="mt-1 text-sm font-bold text-[var(--color-ink)] line-clamp-2 leading-snug group-hover:text-[var(--color-food)] transition-colors">
                    {item.name}
                  </h3>

                  <div className="mt-4 flex items-baseline gap-2">
                    <span className="text-base font-extrabold text-[var(--color-food)]">
                      {item.price.toLocaleString("vi-VN")} đ
                    </span>
                    <span className="text-xs text-[var(--color-muted)] line-through">
                      {item.oldPrice.toLocaleString("vi-VN")} đ
                    </span>
                  </div>
                </div>
              </div>

              {/* Order CTA */}
              <div className="p-5 pt-0">
                <a
                  href="#download"
                  className="flex w-full items-center justify-center gap-2 rounded-xl bg-orange-500/10 py-2.5 text-xs font-bold text-[var(--color-food)] transition-all hover:bg-[var(--color-food)] hover:text-white"
                >
                  <span>Đặt món ngay</span>
                  <span>→</span>
                </a>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
