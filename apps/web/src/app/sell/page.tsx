import Link from "next/link";
import { listings, sellerDashboardMetrics } from "@homeowner/domain";
import { AppShell, SectionHeading, StatCard } from "@homeowner/ui";
import { ListingWizard } from "./listing-wizard";

const mobileNavItems = [
  { href: "/", label: "Home" },
  { href: "/buy", label: "Buy" },
  { href: "/sell", label: "Sell" },
  { href: "/messages", label: "Inbox" },
  { href: "/offers", label: "Offers" },
];

export default function SellPage() {
  const sellerListings = listings.slice(0, 3);

  return (
    <AppShell
      mobileNavItems={mobileNavItems}
      nav={
        <>
          <Link href="/">Home</Link>
          <Link href="/buy">Buy</Link>
          <Link href="/sell">Sell</Link>
          <Link href="/messages">Messages</Link>
          <Link href="/offers">Offers</Link>
        </>
      }
    >
      <div className="space-y-12">
        <SectionHeading
          eyebrow="Seller workspace"
          title="Run a serious private-sale process without a cluttered dashboard"
          description="This page now carries a real vertical slice: seller metrics, a calm task view, and an autosaving listing wizard that pushes sellers toward trustworthy publish readiness."
        />

        <div className="grid gap-4 md:grid-cols-4">
          <StatCard label="Active listings" value={sellerDashboardMetrics.activeListings} />
          <StatCard label="Draft listings" value={sellerDashboardMetrics.draftListings} />
          <StatCard label="Enquiry threads" value={sellerDashboardMetrics.enquiryThreads} />
          <StatCard label="Live offers" value={sellerDashboardMetrics.liveOffers} />
        </div>

        <div className="grid gap-6 xl:grid-cols-[0.9fr_1.1fr]">
          <section className="space-y-4 rounded-[32px] border border-slate-200 bg-white p-6 shadow-sm shadow-slate-200/50">
            <h2 className="text-xl font-semibold tracking-tight text-slate-950">Seller priorities</h2>
            <div className="space-y-3">
              {[
                "Confirm seller authority and legal pack readiness before publish.",
                "Keep the first inspection slot visible so buyers can act quickly.",
                "Use the owner summary to sound clear and credible, not salesy.",
              ].map((item) => (
                <div className="rounded-2xl border border-slate-200 bg-slate-50 px-4 py-4 text-sm text-slate-700" key={item}>
                  {item}
                </div>
              ))}
            </div>

            <div className="rounded-[28px] border border-slate-200 bg-slate-950 p-5 text-white">
              <p className="text-xs font-semibold uppercase tracking-[0.22em] text-teal-300">
                Current pipeline
              </p>
              <div className="mt-4 space-y-4">
                {sellerListings.map((listing) => (
                  <div className="rounded-2xl border border-white/10 bg-white/5 p-4" key={listing.id}>
                    <div className="flex items-start justify-between gap-4">
                      <div>
                        <p className="font-semibold">{listing.title}</p>
                        <p className="mt-1 text-sm text-slate-300">{listing.address.suburb}</p>
                      </div>
                      <span className="rounded-full bg-white/10 px-3 py-1 text-xs font-semibold uppercase tracking-[0.18em] text-slate-200">
                        {listing.status.replaceAll("_", " ")}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </section>

          <ListingWizard />
        </div>
      </div>
    </AppShell>
  );
}
