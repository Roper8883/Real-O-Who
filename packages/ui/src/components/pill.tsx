import clsx from "clsx";
import type { PropsWithChildren } from "react";

interface PillProps extends PropsWithChildren {
  tone?: "neutral" | "success" | "warning" | "accent";
}

export function Pill({ children, tone = "neutral" }: PillProps) {
  return (
    <span
      className={clsx(
        "inline-flex items-center rounded-full border px-3 py-1 text-xs font-semibold uppercase tracking-[0.16em]",
        tone === "neutral" && "border-slate-300 bg-white text-slate-700",
        tone === "success" && "border-emerald-200 bg-emerald-50 text-emerald-800",
        tone === "warning" && "border-amber-200 bg-amber-50 text-amber-800",
        tone === "accent" && "border-sky-200 bg-sky-50 text-sky-800",
      )}
    >
      {children}
    </span>
  );
}
