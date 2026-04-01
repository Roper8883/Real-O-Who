import Link from "next/link";
import { listings, sellerDashboardMetrics } from "@homeowner/domain";
import { AppShell, Pill, PropertyCard, SectionHeading, StatCard } from "@homeowner/ui";

const featuredListings = listings.slice(0, 3);
const mobileNavItems = [
  { href: "/buy", label: "Buy" },
  { href: "/sell", label: "Sell" },
  { href: "/messages", label: "Inbox" },
  { href: "/offers", label: "Offers" },
  { href: "/profile", label: "Profile" },
];

export default function HomePage() {
  return (
    <AppShell
      mobileNavItems={mobileNavItems}
      nav={
        <>
          <Link href="/buy">Buy</Link>
          <Link href="/sell">Sell</Link>
          <Link href="/messages">Messages</Link>
          <Link href="/offers">Offers</Link>
          <Link href="/profile">Profile</Link>
        </>
      }
    >
      <div className="space-y-20">
        <section className="grid gap-10 lg:grid-cols-[1.25fr_0.75fr] lg:items-end">
          <div className="space-y-8">
            <div className="flex flex-wrap gap-3">
              <Pill tone="accent">Private treaty only</Pill>
              <Pill tone="neutral">Australia-wide rules engine</Pill>
              <Pill tone="success">Owner to buyer direct messaging</Pill>
            </div>
            <div className="max-w-4xl space-y-6">
              <h1 className="font-serif text-5xl leading-tight tracking-tight text-slate-950 sm:text-6xl">
                Sell privately with the trust, structure, and workflow buyers expect.
              </h1>
              <p className="max-w-3xl text-lg leading-8 text-slate-600">
                Homeowner helps owners list residential property directly to buyers without
                pretending to be an agent, law firm, trust account, or conveyancer. Search,
                disclosures, inspections, offers, and document handover are state-aware from
                day one.
              </p>
            </div>
            <div className="flex flex-wrap gap-4">
              <Link
                className="rounded-full bg-slate-950 px-6 py-3 text-sm font-semibold text-white transition hover:bg-slate-800"
                href="/buy"
              >
                Explore listings
              </Link>
              <Link
                className="rounded-full border border-slate-300 bg-white px-6 py-3 text-sm font-semibold text-slate-900 transition hover:border-slate-400"
                href="/sell"
              >
                Start a seller dashboard
              </Link>
            </div>
          </div>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-1">
            <StatCard
              label="Live buyer activity"
              value={sellerDashboardMetrics.savedByBuyers}
              detail="Saved properties tracked across shortlisted private-sale homes."
            />
            <StatCard
              label="Upcoming inspections"
              value={sellerDashboardMetrics.upcomingInspections}
              detail="Owner-managed open homes and private appointments in the next 7 days."
            />
            <StatCard
              label="Compliance tasks"
              value={sellerDashboardMetrics.complianceTasks}
              detail="State-based disclosure tasks that need review before publication or exchange."
            />
          </div>
        </section>

        <section className="space-y-8">
          <SectionHeading
            eyebrow="Featured now"
            title="High-trust private listings"
            description="Every featured home below is backed by a seller profile, disclosure status, inspection options, and the direct owner workflow."
          />
          <div className="grid gap-6 lg:grid-cols-3">
            {featuredListings.map((listing) => (
              <Link href={`/property/${listing.slug}`} key={listing.id}>
                <PropertyCard listing={listing} />
              </Link>
            ))}
          </div>
        </section>

        <section className="grid gap-6 lg:grid-cols-3">
          {[
            {
              title: "Search that feels familiar",
              body: "Map-ready browsing, serious filters, saved searches, and comparable-sale hooks give buyers confidence without diluting the direct-owner model.",
            },
            {
              title: "State-aware compliance",
              body: "NSW contract-gating, VIC Section 32 support, ACT report workflows, Queensland disclosure delivery, and buyer-beware prompts are built into the platform rules.",
            },
            {
              title: "Offers without false legal finality",
              body: "Make offer, counter, accept in principle, request contract, and move into legal review with clear non-binding warnings every step of the way.",
            },
          ].map((item) => (
            <article
              className="rounded-[30px] border border-slate-200 bg-white/90 p-7 shadow-sm shadow-slate-200/40"
              key={item.title}
            >
              <h3 className="text-xl font-semibold tracking-tight text-slate-950">
                {item.title}
              </h3>
              <p className="mt-3 text-sm leading-7 text-slate-600">{item.body}</p>
            </article>
          ))}
        </section>
      </div>
    </AppShell>
  );
}
