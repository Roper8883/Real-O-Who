import Link from "next/link";
import { listings } from "@homeowner/domain";
import { AppShell, Pill, PropertyCard, SectionHeading } from "@homeowner/ui";

export default function BuyPage() {
  return (
    <AppShell
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
      <div className="space-y-10">
        <SectionHeading
          eyebrow="Search"
          title="Map-ready buyer search"
          description="A responsive search workspace with state-aware filters, direct-owner trust signals, and enough detail to compare homes without friction."
        />

        <section className="grid gap-8 lg:grid-cols-[360px_1fr]">
          <aside className="space-y-6 rounded-[30px] border border-slate-200 bg-white p-6 shadow-sm shadow-slate-200/50">
            <div>
              <p className="text-xs font-semibold uppercase tracking-[0.22em] text-sky-700">
                Filters
              </p>
              <h3 className="mt-2 text-2xl font-semibold tracking-tight text-slate-950">
                Buyer priorities
              </h3>
            </div>
            <div className="flex flex-wrap gap-2">
              <Pill tone="accent">Seller verified</Pill>
              <Pill tone="neutral">Has documents</Pill>
              <Pill tone="neutral">Open home</Pill>
              <Pill tone="neutral">Pool</Pill>
              <Pill tone="neutral">Study</Pill>
              <Pill tone="neutral">Accessibility features</Pill>
            </div>
            <div className="space-y-3 text-sm leading-7 text-slate-600">
              <p>Current viewport search and polygon-draw interactions are scaffolded for the map adapter layer.</p>
              <p>URL-safe search serialization is ready in the shared search package, so saved searches and alerts can stay stable across devices.</p>
            </div>
          </aside>

          <div className="space-y-6">
            <div className="rounded-[30px] border border-slate-200 bg-[linear-gradient(135deg,#dbeafe_0%,#ecfeff_50%,#f8fafc_100%)] p-6">
              <div className="flex items-center justify-between gap-4">
                <div>
                  <p className="text-xs font-semibold uppercase tracking-[0.22em] text-sky-700">
                    Map preview
                  </p>
                  <p className="mt-2 text-sm text-slate-600">
                    Clustering, draw-on-map, and viewport search are designed into the API and UI contracts.
                  </p>
                </div>
                <Pill tone="accent">Map adapter ready</Pill>
              </div>
              <div className="mt-5 grid grid-cols-6 gap-3">
                {Array.from({ length: 18 }).map((_, index) => (
                  <div
                    className={`h-16 rounded-2xl ${
                      index % 5 === 0 ? "bg-sky-300/80" : "bg-white/60"
                    }`}
                    key={index}
                  />
                ))}
              </div>
            </div>

            <div className="grid gap-6 xl:grid-cols-2">
              {listings.map((listing) => (
                <Link href={`/property/${listing.slug}`} key={listing.id}>
                  <PropertyCard listing={listing} />
                </Link>
              ))}
            </div>
          </div>
        </section>
      </div>
    </AppShell>
  );
}
