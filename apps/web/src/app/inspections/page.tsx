import Link from "next/link";
import { inspectionBookings, listings, serviceProviders } from "@homeowner/domain";
import { AppShell, Pill, SectionHeading } from "@homeowner/ui";

const mobileNavItems = [
  { href: "/buy", label: "Buy" },
  { href: "/saved", label: "Saved" },
  { href: "/inspections", label: "Schedule" },
  { href: "/messages", label: "Inbox" },
  { href: "/offers", label: "Offers" },
];

export default function InspectionsPage() {
  return (
    <AppShell
      mobileNavItems={mobileNavItems}
      nav={
        <>
          <Link href="/">Home</Link>
          <Link href="/buy">Buy</Link>
          <Link href="/inspections">Inspections</Link>
          <Link href="/offers">Offers</Link>
        </>
      }
    >
      <div className="space-y-8">
        <SectionHeading
          eyebrow="Inspections"
          title="Owner-managed inspections and building/pest pathways"
          description="Book open homes, request private appointments, or move into a seller-provided report flow or third-party building and pest provider booking."
        />

        <section className="grid gap-6 lg:grid-cols-2">
          <article className="rounded-[30px] border border-slate-200 bg-white p-6">
            <h2 className="text-lg font-semibold text-slate-950">Upcoming buyer bookings</h2>
            <div className="mt-4 space-y-4">
              {inspectionBookings.map((booking) => {
                const listing = listings.find((item) => item.id === booking.listingId);
                return (
                  <div className="rounded-2xl border border-slate-200 p-4" key={booking.id}>
                    <div className="flex items-center justify-between gap-4">
                      <div>
                        <p className="font-semibold text-slate-900">{listing?.title}</p>
                        <p className="text-sm text-slate-600">{booking.note}</p>
                      </div>
                      <Pill tone="accent">{booking.status}</Pill>
                    </div>
                  </div>
                );
              })}
            </div>
          </article>
          <article className="rounded-[30px] border border-slate-200 bg-white p-6">
            <h2 className="text-lg font-semibold text-slate-950">Building and pest providers</h2>
            <div className="mt-4 space-y-4">
              {serviceProviders.map((provider) => (
                <div className="rounded-2xl border border-slate-200 p-4" key={provider.id}>
                  <div className="flex items-center justify-between gap-4">
                    <p className="font-semibold text-slate-900">{provider.businessName}</p>
                    <Pill tone={provider.licenceVerified ? "success" : "warning"}>
                      {provider.licenceVerified ? "Verified" : "Review"}
                    </Pill>
                  </div>
                  <p className="mt-2 text-sm leading-7 text-slate-600">
                    {provider.description}
                  </p>
                </div>
              ))}
            </div>
          </article>
        </section>
      </div>
    </AppShell>
  );
}
