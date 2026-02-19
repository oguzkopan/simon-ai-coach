"use client";

import { useEffect } from "react";

export function ClientThemeWrapper() {
  useEffect(() => {
    // Initialize theme on mount
    const stored = localStorage.getItem("theme");
    const root = window.document.documentElement;
    
    root.classList.remove("light", "dark");
    
    if (stored === "dark" || stored === "light") {
      root.classList.add(stored);
    } else {
      const systemTheme = window.matchMedia("(prefers-color-scheme: dark)").matches
        ? "dark"
        : "light";
      root.classList.add(systemTheme);
    }
  }, []);

  return null;
}
