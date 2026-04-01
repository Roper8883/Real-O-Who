import type { PropsWithChildren, ReactNode } from "react";

export interface AppShellNavItem {
  href: string;
  label: string;
}

interface AppShellProps extends PropsWithChildren {
  nav: ReactNode;
  mobileNavItems?: AppShellNavItem[];
}

export function AppShell({ nav, mobileNavItems = [], children }: AppShellProps) {
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
      <main className="mx-auto max-w-7xl px-6 py-10 pb-28 lg:px-10 lg:pb-10">{children}</main>
      {mobileNavItems.length > 0 ? (
        <nav className="fixed inset-x-4 bottom-4 z-40 md:hidden">
          <div className="grid grid-cols-5 gap-2 rounded-[28px] border border-white/70 bg-white/92 p-2 shadow-lg shadow-slate-300/30 backdrop-blur">
            {mobileNavItems.map((item) => (
              <a
                className="rounded-[20px] px-3 py-3 text-center text-[11px] font-semibold leading-tight text-slate-700 transition hover:bg-slate-100"
                href={item.href}
                key={`${item.href}-${item.label}`}
              >
                {item.label}
              </a>
            ))}
          </div>
        </nav>
      ) : null}
    </div>
  );
}
