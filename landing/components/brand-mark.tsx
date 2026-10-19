export function BrandMark({
  size = "md",
  showWordmark = true,
  showTagline = false,
  className = "",
}: {
  size?: "sm" | "md" | "lg";
  showWordmark?: boolean;
  showTagline?: boolean;
  className?: string;
}) {
  const sizeMap = {
    sm: {
      box: "h-7 w-7 rounded-lg",
      text: "text-lg",
      tagline: "text-[8px]",
    },
    md: {
      box: "h-9 w-9 rounded-xl",
      text: "text-xl",
      tagline: "text-[9px]",
    },
    lg: {
      box: "h-12 w-12 rounded-2xl",
      text: "text-2xl sm:text-3xl",
      tagline: "text-[10px]",
    },
  };

  const current = sizeMap[size];

  return (
    <div className={`inline-flex items-center gap-2.5 ${className}`}>
      {/* Official DealGo Squircle Icon with Interlocking Arcs */}
      <span
        className={`relative flex ${current.box} shrink-0 items-center justify-center bg-gradient-to-br from-[#1e1b4b] via-[#2e1065] to-[#090a0f] p-1 shadow-sm shadow-purple-900/30 ring-1 ring-white/10`}
      >
        <svg
          className="h-full w-full"
          viewBox="0 0 32 32"
          fill="none"
          aria-hidden="true"
        >
          <defs>
            <linearGradient
              id="bm-deal"
              x1="4"
              y1="4"
              x2="28"
              y2="28"
              gradientUnits="userSpaceOnUse"
            >
              <stop offset="0%" stopColor="#c084fc" />
              <stop offset="100%" stopColor="#8b5cf6" />
            </linearGradient>
            <linearGradient
              id="bm-go"
              x1="28"
              y1="28"
              x2="4"
              y2="4"
              gradientUnits="userSpaceOnUse"
            >
              <stop offset="0%" stopColor="#34d399" />
              <stop offset="100%" stopColor="#059669" />
            </linearGradient>
          </defs>

          {/* Deal Wave Arc (Purple - Negotiation & Consensus) */}
          <path
            d="M10 16C10 11.5 13.5 8 18 8C20.8 8 23.3 9.4 24.8 11.6C25.2 12.3 24.8 13.2 24 13.5C23.2 13.7 22.4 13.2 22 12.5C21.1 11 19.6 10 17.8 10C14.5 10 11.8 12.7 11.8 16C11.8 17.5 12.4 18.9 13.3 20C13.9 20.7 13.6 21.8 12.7 22.1C11.8 22.5 10.8 22 10.3 21.2C9.5 19.7 9 17.9 9 16H10Z"
            fill="url(#bm-deal)"
          />

          {/* Go Wave Arc (Emerald Green - 2-Wheel Movement & Speed) */}
          <path
            d="M22 16C22 20.5 18.5 24 14 24C11.2 24 8.7 22.6 7.2 20.4C6.8 19.7 7.2 18.8 8 18.5C8.8 18.3 9.6 18.8 10 19.5C10.9 21 12.4 22 14.2 22C17.5 22 20.2 19.3 20.2 16C20.2 14.5 19.6 13.1 18.7 12C18.1 11.3 18.4 10.2 19.3 9.9C20.2 9.5 21.2 10 21.7 10.8C22.5 12.3 23 14.1 23 16H22Z"
            fill="url(#bm-go)"
          />

          {/* Central Deal D Core */}
          <path
            d="M13.5 12.5H17C18.9 12.5 20.5 14.1 20.5 16C20.5 17.9 18.9 19.5 17 19.5H13.5V12.5ZM15.5 14.5V17.5H16.8C17.7 17.5 18.5 16.8 18.5 16C18.5 15.2 17.7 14.5 16.8 14.5H15.5Z"
            fill="#ffffff"
          />

          {/* Food Energy Accent Dot */}
          <circle cx="19.5" cy="12.5" r="1.5" fill="#f97316" />
        </svg>
      </span>

      {/* Typography: "Deal" (Purple) + "Go" (Emerald Green) */}
      {showWordmark && (
        <div className="flex flex-col">
          <div className="flex items-center gap-1.5 leading-none">
            <span className={`${current.text} font-black tracking-tight`}>
              <span className="text-[var(--color-brand)]">Deal</span>
              <span className="text-[var(--color-success)]">Go</span>
            </span>
            <span className="rounded-full bg-emerald-500/10 px-1.5 py-0.5 text-[9px] font-bold text-emerald-600 dark:text-emerald-400">
              VN
            </span>
          </div>
          {showTagline && (
            <span
              className={`${current.tagline} font-bold tracking-widest text-[var(--color-muted)] uppercase mt-0.5`}
            >
              Ride &amp; Food Platform
            </span>
          )}
        </div>
      )}
    </div>
  );
}
