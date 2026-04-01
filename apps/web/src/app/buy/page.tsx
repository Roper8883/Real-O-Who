import { Suspense } from "react";
import Link from "next/link";
import { AppShell } from "@homeowner/ui";
import { SearchExperience } from "./search-experience";

const mobileNavItems = [
  { href: "/buy", label: "Buy" },
  { href: "/saved", label: "Saved" },
  { href: "/messages", label: "Inbox" },
  { href: "/inspections", label: "Schedule" },
  { href: "/profile", label: "Profile" },
];

export default function BuyPage() {
  return (
    <AppShell
      mobileNavItems={mobileNavItems}
      nav={
        <>
          <Link href="/">Home</Link>
          <Link href="/buy">Search</Link>
          <Link href="/saved">Saved</Link>
          <Link href="/messages">Messages</Link>
          <Link href="/inspections">Inspections</Link>
        </>
      }
    >
      <Suspense fallback={<div className="rounded-[28px] border border-slate-200 bg-white p-6 text-sm text-slate-600">Loading buyer search…</div>}>
        <SearchExperience />
      </Suspense>
    </AppShell>
  );
}
