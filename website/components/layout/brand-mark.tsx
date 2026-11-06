import Image from "next/image";

export function BrandMark({
  showIcon = true,
  compact = false,
  className = "",
}: {
  showIcon?: boolean;
  compact?: boolean;
  className?: string;
}) {
  if (!showIcon) {
    return (
      <span className={`text-xl font-bold tracking-tight ${className}`}>
        <span className="text-brand">Deal</span>
        <span className="text-success">Go</span>
      </span>
    );
  }

  return (
    <span className={`inline-flex items-center ${className}`}>
      <Image
        src={compact ? "/dealgo-icon.svg" : "/dealgo-logo.svg"}
        alt="DealGo"
        width={compact ? 512 : 1500}
        height={512}
        priority
        unoptimized
        className={compact ? "size-9 max-h-full max-w-full" : "h-9 w-auto"}
      />
    </span>
  );
}
