import Link from "next/link";
import { listings, sellerDashboardMetrics } from "@homeowner/domain";
import { AppShell, SectionHeading, StatCard } from "@homeowner/ui";

export default function SellPage() {
  const sellerListings = listings.slice(0, 4);

  return (
    <AppShell
      nav={
        <>
          <Link href="/">Home</Link>
          <Link href="/sell">Seller dashboard</Link>
          <Link href="/messages">Enquiries</Link>
          <Link href="/offers">Offers</Link>
        </>
      }
    >
      <div className="space-y-10">
        <SectionHeading
          eyebrow="Seller workspace"
          title="A serious private-sale dashboard for homeowners"
          description="Track disclosure readiness, enquiries, inspections, offers, and tasks to publish without pretending the platform replaces legal review or regulated settlement handling."
        />
        <div className="grid gap-4 md:grid-cols-4">
          <StatCard label="Active listings" value={sellerDashboardMetrics.activeListings} />
          <StatCard label="Draft listings" value={sellerDashboardMetrics.draftListings} />
          <StatCard label="Enquiry threads" value={sellerDashboardMetrics.enquiryThreads} />
          <StatCard label="Live offers" value={sellerDashboardMetrics.liveOffers} />
        </div>
        <section className="rounded-[32px] border border-slate-200 bg-white p-6">
          <h2 className="text-lg font-semibold text-slate-950">Listing pipeline</h2>
          <div className="mt-5 grid gap-4 md:grid-cols-2">
            {sellerListings.map((listing) => (
              <div className="rounded-2xl border border-slate-200 p-4" key={listing.id}>
                <div className="flex items-center justify-between gap-4">
                  <div>
                    <p className="font-semibold text-slate-900">{listing.title}</p>
                    <p className="text-sm text-slate-600">{listing.address.suburb}</p>
                  </div>
                  <span className="text-sm font-medium text-slate-500">
                    {listing.legalDisclosureStatus.replaceAll("_", " ")}
                  </span>
                </div>
              </div>
            ))}
          </div>
        </section>
      </div>
    </AppShell>
  );
}
