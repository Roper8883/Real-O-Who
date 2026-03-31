import Link from "next/link";
import { listings, offerThreads } from "@homeowner/domain";
import { AppShell, Pill, SectionHeading } from "@homeowner/ui";

export default function OffersPage() {
  return (
    <AppShell
      nav={
        <>
          <Link href="/">Home</Link>
          <Link href="/buy">Buy</Link>
          <Link href="/offers">Offers</Link>
          <Link href="/profile">Profile</Link>
        </>
      }
    >
      <div className="space-y-8">
        <SectionHeading
          eyebrow="Offers"
          title="Structured, non-binding negotiation"
          description="Buyers can make offers with finance, building, pest, and sale-of-home conditions. Sellers can counter or accept in principle without creating false legal finality."
        />

        <div className="grid gap-6">
          {offerThreads.map((thread) => {
            const listing = listings.find((item) => item.id === thread.listingId);
            const latestVersion = thread.versions.at(-1);
            return (
              <article
                className="rounded-[30px] border border-slate-200 bg-white p-6"
                key={thread.id}
              >
                <div className="flex flex-wrap items-start justify-between gap-4">
                  <div className="space-y-2">
                    <p className="text-sm text-slate-500">{listing?.title}</p>
                    <h2 className="text-2xl font-semibold tracking-tight text-slate-950">
                      {latestVersion ? `$${latestVersion.amount.toLocaleString()}` : "Offer pending"}
                    </h2>
                    <p className="text-sm text-slate-600">{latestVersion?.message}</p>
                  </div>
                  <Pill tone="warning">{thread.status.replaceAll("_", " ")}</Pill>
                </div>
                <div className="mt-6 grid gap-4 md:grid-cols-3">
                  {thread.disclaimers.map((disclaimer) => (
                    <div className="rounded-2xl bg-amber-50 p-4 text-sm leading-6 text-amber-900" key={disclaimer}>
                      {disclaimer}
                    </div>
                  ))}
                </div>
              </article>
            );
          })}
        </div>
      </div>
    </AppShell>
  );
}
