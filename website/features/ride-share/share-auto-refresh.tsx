"use client";

import { useRouter } from "next/navigation";
import { useEffect } from "react";

/**
 * Re-renders the server page every `delayMs` while the tab is visible (paused when hidden,
 * immediate refresh on return). The server stops rendering this component once the trip
 * ended or the link expired, which unmounts it and clears the timer.
 */
export function ShareAutoRefresh({ delayMs }: { delayMs: number }) {
  const router = useRouter();
  useEffect(() => {
    let timer: ReturnType<typeof setTimeout> | undefined;
    const schedule = () => {
      clearTimeout(timer);
      if (document.visibilityState !== "visible") return;
      timer = setTimeout(() => {
        router.refresh();
        schedule();
      }, delayMs);
    };
    const onVisibility = () => {
      if (document.visibilityState === "visible") {
        router.refresh();
        schedule();
      } else {
        clearTimeout(timer);
      }
    };
    schedule();
    document.addEventListener("visibilitychange", onVisibility);
    return () => {
      clearTimeout(timer);
      document.removeEventListener("visibilitychange", onVisibility);
    };
  }, [router, delayMs]);
  return null;
}
