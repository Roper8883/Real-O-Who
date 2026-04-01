import Link from "next/link";
import { listings } from "@homeowner/domain";
import { AppShell, Pill, SectionHeading } from "@homeowner/ui";

const mobileNavItems = [
  { href: "/", label: "Home" },
  { href: "/listings", label: "Listings" },
  { href: "/users", label: "Users" },
  { href: "/reports", label: "Reports" },
  { href: "/rules", label: "Rules" },
];

export default function AdminListingsPage() {
  return (
    <AppShell
      mobileNavItems={mobileNavItems}
      nav={
        <>
          <Link href="/">Overview</Link>
          <Link href="/listings">Listings</Link>
          <Link href="/users">Users</Link>
          <Link href="/rules">Rules</Link>
        </>
      }
    >
      <div className="space-y-8">
        <SectionHeading
          eyebrow="Listings review"
          title="Moderate property publication and legal readiness"
          description="Listing review combines seller verification, disclosure completeness, media quality, and fraud checks before or after publication."
        />
        <div className="grid gap-4">
          {listings.map((listing) => (
            <article className="rounded-[28px] border border-slate-200 bg-white p-5" key={listing.id}>
              <div className="flex flex-wrap items-center justify-between gap-4">
                <div>
                  <p className="font-semibold text-slate-950">{listing.title}</p>
                  <p className="text-sm text-slate-600">
                    {listing.address.suburb}, {listing.address.state}
                  </p>
                </div>
                <div className="flex flex-wrap gap-2">
                  <Pill tone={listing.sellerVerified ? "success" : "warning"}>
                    {listing.sellerVerified ? "seller verified" : "seller pending"}
                  </Pill>
                  <Pill tone="accent">{listing.legalDisclosureStatus.replaceAll("_", " ")}</Pill>
                </div>
              </div>
            </article>
          ))}
        </div>
      </div>
    </AppShell>
  );
}
