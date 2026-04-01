import Link from "next/link";
import { listings, savedProperties } from "@homeowner/domain";
import { AppShell, Pill, PropertyCard, SectionHeading } from "@homeowner/ui";

const mobileNavItems = [
  { href: "/buy", label: "Buy" },
  { href: "/saved", label: "Saved" },
  { href: "/inspections", label: "Schedule" },
  { href: "/messages", label: "Inbox" },
  { href: "/profile", label: "Profile" },
];

export default function SavedPage() {
  const savedListings = savedProperties
    .map((savedProperty) => listings.find((listing) => listing.id === savedProperty.listingId))
    .filter(Boolean);

  return (
    <AppShell
      mobileNavItems={mobileNavItems}
      nav={
        <>
          <Link href="/">Home</Link>
          <Link href="/buy">Buy</Link>
          <Link href="/saved">Saved</Link>
          <Link href="/offers">Offers</Link>
        </>
      }
    >
      <div className="space-y-8">
        <SectionHeading
          eyebrow="Saved properties"
          title="Shortlists, collections, and due diligence notes"
          description="Buyers can organise properties into collections, add private notes, mark inspection progress, and keep only the homes that still matter."
        />
        <div className="grid gap-6 lg:grid-cols-2">
          {savedListings.map((listing, index) =>
            listing ? (
              <div className="space-y-4" key={listing.id}>
                <div className="flex items-center gap-3">
                  <Pill tone="neutral">{savedProperties[index]?.collection}</Pill>
                  <Pill tone="accent">{savedProperties[index]?.status}</Pill>
                </div>
                <PropertyCard listing={listing} />
              </div>
            ) : null,
          )}
        </div>
      </div>
    </AppShell>
  );
}
