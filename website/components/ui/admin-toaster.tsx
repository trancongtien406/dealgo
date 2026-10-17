"use client";

import { Toaster } from "sonner";

export function AdminToaster() {
  return (
    <Toaster
      position="top-right"
      closeButton
      richColors
      toastOptions={{
        classNames: {
          toast:
            "border border-border bg-white text-ink shadow-lg !font-[inherit]",
          title: "text-sm font-semibold text-ink",
          description: "text-sm text-muted",
          closeButton: "border-border bg-white text-muted",
        },
      }}
    />
  );
}
