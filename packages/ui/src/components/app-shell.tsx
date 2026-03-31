import type { PropsWithChildren, ReactNode } from "react";

interface AppShellProps extends PropsWithChildren {
  nav: ReactNode;
}

export function AppShell({ nav, children }: AppShellProps) {
  return (
    <div className="min-h-screen bg-[linear-gradient(180deg,#f7fbff_0%,#edf4f8_32%,#f8fafc_100%)] text-slate-900">
      <header className="border-b border-white/60 bg-white/80 backdrop-blur">
        <div className="mx-auto flex max-w-7xl items-center justify-between px-6 py-4 lg:px-10">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.24em] text-sky-700">
              Homeowner
            </p>
            <p className="text-sm text-slate-600">
              Private property sale platform for Australia
            </p>
          </div>
          <nav className="hidden gap-6 text-sm font-medium text-slate-700 md:flex">
            {nav}
          </nav>
        </div>
      </header>
      <main className="mx-auto max-w-7xl px-6 py-10 lg:px-10">{children}</main>
    </div>
  );
}
