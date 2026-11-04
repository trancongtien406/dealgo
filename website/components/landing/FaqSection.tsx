"use client";

import { useState } from "react";
import { LANDING_FAQS } from "./faq-content";

export default function FaqSection() {
  const [openIndex, setOpenIndex] = useState<number | null>(null);

  return (
    <div className="bg-white rounded-[24px] p-5 sm:p-6 border border-gray-100 shadow-[0_4px_24px_-4px_rgba(0,0,0,0.03)] h-full flex flex-col justify-between">
      {/* Header with Title and Inline Subtext */}
      <div className="flex flex-wrap items-baseline gap-2 mb-4 pb-2 border-b border-gray-100">
        <h2 className="text-base sm:text-lg font-extrabold text-[#2E1065] tracking-tight">
          Câu hỏi thường gặp
        </h2>
        <span className="text-xs text-gray-500 font-normal">
          Giải đáp một số thắc mắc phổ biến về DealGo.
        </span>
      </div>

      {/* Accordion List */}
      <div className="divide-y divide-gray-100 flex-1">
        {LANDING_FAQS.map((faq, i) => {
          const isOpen = openIndex === i;
          return (
            <div key={i} className="py-2.5 sm:py-3 transition-colors">
              <button
                type="button"
                className="w-full flex items-center justify-between text-left gap-3 group cursor-pointer"
                onClick={() => setOpenIndex(isOpen ? null : i)}
                aria-expanded={isOpen}
              >
                <span
                  className={`text-xs sm:text-[13px] font-medium transition-colors ${
                    isOpen ? "text-[#6D28D9] font-semibold" : "text-[#1E293B] group-hover:text-[#6D28D9]"
                  }`}
                >
                  {faq.q}
                </span>

                <span
                  className={`text-gray-400 group-hover:text-[#6D28D9] text-xs transition-transform duration-200 ${
                    isOpen ? "rotate-90 text-[#6D28D9]" : ""
                  }`}
                >
                  ›
                </span>
              </button>

              {isOpen && (
                <div className="mt-2 text-xs text-gray-500 leading-relaxed pr-4 animate-fadeIn">
                  {faq.a}
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
