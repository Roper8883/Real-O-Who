import Image from "next/image";
import Link from "next/link";
import { listings } from "@homeowner/domain";
import { AppShell, Pill, SectionHeading } from "@homeowner/ui";

const mobileNavItems = [
  { href: "/buy", label: "Buy" },
  { href: "/saved", label: "Saved" },
  { href: "/messages", label: "Inbox" },
  { href: "/inspections", label: "Schedule" },
  { href: "/offers", label: "Offer" },
];

export function generateStaticParams() {
  return listings.map((listing) => ({ slug: listing.slug }));
}

export default async function PropertyDetailPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const listing = listings.find((entry) => entry.slug === slug);

  if (!listing) {
    return <div>Listing not found.</div>;
  }

  const structuredData = {
    "@context": "https://schema.org",
    "@type": "SingleFamilyResidence",
    name: listing.title,
    description: listing.description,
    url: `https://homeowner.example.com/property/${listing.slug}`,
    image: listing.heroMedia.map((media) => media.url),
    address: {
      "@type": "PostalAddress",
      streetAddress: listing.address.line1,
      addressLocality: listing.address.suburb,
      postalCode: listing.address.postcode,
      addressRegion: listing.address.state,
      addressCountry: "AU",
    },
    numberOfBedrooms: listing.facts.bedrooms,
    numberOfBathroomsTotal: listing.facts.bathrooms,
    floorSize: listing.facts.buildingSizeSqm
      ? {
          "@type": "QuantitativeValue",
          value: listing.facts.buildingSizeSqm,
          unitCode: "MTK",
        }
      : undefined,
    offers: {
      "@type": "Offer",
      priceCurrency: "AUD",
      price: listing.askingPrice ?? undefined,
      availability:
        listing.status === "sold"
          ? "https://schema.org/SoldOut"
          : "https://schema.org/InStock",
    },
  };

  return (
    <AppShell
      mobileNavItems={mobileNavItems}
      nav={
        <>
          <Link href="/">Home</Link>
          <Link href="/buy">Search</Link>
          <Link href="/messages">Ask owner</Link>
          <Link href="/offers">Offers</Link>
        </>
      }
    >
      <div className="space-y-10">
        <script
          dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData) }}
          type="application/ld+json"
        />
        <section className="grid gap-8 lg:grid-cols-[1.35fr_0.65fr]">
          <div className="space-y-6">
            <div className="relative aspect-[16/10] overflow-hidden rounded-[34px] border border-slate-200 bg-slate-100">
              <Image
                alt={listing.title}
                className="object-cover"
                fill
                sizes="(max-width: 1024px) 100vw, 66vw"
                src={listing.heroMedia[0]?.url ?? listing.coverImage}
              />
            </div>
            <div className="grid gap-4 sm:grid-cols-3">
              {listing.heroMedia.slice(0, 3).map((media) => (
                <div
                  className="relative aspect-[4/3] overflow-hidden rounded-[24px] border border-slate-200 bg-slate-100"
                  key={media.id}
                >
                  <Image
                    alt={media.altText}
                    className="object-cover"
                    fill
                    sizes="(max-width: 640px) 100vw, 33vw"
                    src={media.url}
                  />
                </div>
              ))}
            </div>
          </div>

          <aside className="space-y-6 rounded-[34px] border border-slate-200 bg-white p-7 shadow-sm shadow-slate-200/50">
            <div className="flex flex-wrap gap-2">
              <Pill tone={listing.sellerVerified ? "success" : "warning"}>
                {listing.sellerVerified ? "Seller verified" : "Verification pending"}
              </Pill>
              <Pill tone="accent">{listing.status.replaceAll("_", " ")}</Pill>
              <Pill tone="neutral">{listing.address.state}</Pill>
            </div>
            <div className="space-y-3">
              <h1 className="font-serif text-4xl tracking-tight text-slate-950">
                {listing.priceLabel}
              </h1>
              <p className="text-2xl font-semibold tracking-tight text-slate-950">
                {listing.title}
              </p>
              <p className="text-sm text-slate-600">
                {listing.address.line1}, {listing.address.suburb} {listing.address.postcode}
              </p>
            </div>
            <div className="rounded-2xl border border-emerald-200 bg-emerald-50 p-4 text-sm leading-7 text-emerald-950">
              Listed by {listing.sellerName} through a direct owner workflow. Contact details stay
              masked until both parties choose to reveal them.
            </div>
            <div className="grid grid-cols-2 gap-4 text-sm text-slate-700">
              <div className="rounded-2xl bg-slate-50 p-4">{listing.facts.bedrooms} bedrooms</div>
              <div className="rounded-2xl bg-slate-50 p-4">{listing.facts.bathrooms} bathrooms</div>
              <div className="rounded-2xl bg-slate-50 p-4">{listing.facts.carSpaces} car spaces</div>
              <div className="rounded-2xl bg-slate-50 p-4">
                {listing.facts.landSizeSqm ? `${listing.facts.landSizeSqm} sqm land` : "Land size not supplied"}
              </div>
            </div>
            <div className="space-y-3">
              {[
                { href: "/saved", label: "Save property" },
                { href: "/messages", label: "Ask owner a question" },
                { href: "/inspections", label: "Book inspection" },
                { href: "/offers", label: "Make offer" },
              ].map((action) => (
                <Link
                  className="flex items-center justify-between rounded-2xl border border-slate-200 px-4 py-3 text-sm font-semibold text-slate-900 transition hover:border-slate-300 hover:bg-slate-50"
                  href={action.href}
                  key={action.label}
                >
                  {action.label}
                  <span aria-hidden="true">→</span>
                </Link>
              ))}
            </div>
            <div className="rounded-2xl border border-slate-200 bg-slate-50 p-4">
              <p className="text-sm font-semibold text-slate-900">Inspection availability</p>
              <div className="mt-3 space-y-2 text-sm text-slate-600">
                {listing.inspectionSlots.map((slot) => (
                  <p key={slot.id}>
                    {new Intl.DateTimeFormat("en-AU", {
                      weekday: "short",
                      day: "numeric",
                      month: "short",
                      hour: "numeric",
                      minute: "2-digit",
                    }).format(new Date(slot.startAt))}
                    {" · "}
                    {slot.type === "open_home" ? "Open home" : "Private inspection"}
                  </p>
                ))}
              </div>
            </div>
            <div className="rounded-2xl bg-amber-50 p-4 text-sm leading-7 text-amber-900">
              Offers submitted through the platform are non-binding until a valid contract is
              executed in the legally correct way for {listing.address.state}.
            </div>
          </aside>
        </section>

        <section className="grid gap-8 lg:grid-cols-[1fr_0.8fr]">
          <div className="space-y-8">
            <SectionHeading
              eyebrow="Owner narrative"
              title="What makes this home stand out"
              description={listing.description}
            />
            <div className="grid gap-6 md:grid-cols-2">
              <article className="rounded-[28px] border border-slate-200 bg-white p-6">
                <h2 className="text-lg font-semibold text-slate-950">What the owner loves</h2>
                <ul className="mt-4 space-y-3 text-sm leading-7 text-slate-600">
                  {listing.ownerLoves.map((item) => (
                    <li key={item}>• {item}</li>
                  ))}
                </ul>
              </article>
              <article className="rounded-[28px] border border-slate-200 bg-white p-6">
                <h2 className="text-lg font-semibold text-slate-950">Neighbourhood highlights</h2>
                <ul className="mt-4 space-y-3 text-sm leading-7 text-slate-600">
                  {listing.neighbourhoodHighlights.map((item) => (
                    <li key={item}>• {item}</li>
                  ))}
                </ul>
              </article>
            </div>

            <article className="rounded-[28px] border border-slate-200 bg-white p-6">
              <h2 className="text-lg font-semibold text-slate-950">Documents and disclosure</h2>
              <div className="mt-4 grid gap-4 md:grid-cols-2">
                {listing.requiredDocuments.map((document) => (
                  <div className="rounded-2xl border border-slate-200 p-4" key={document.key}>
                    <div className="flex items-center justify-between gap-4">
                      <p className="font-semibold text-slate-950">{document.title}</p>
                      <Pill tone={document.required ? "warning" : "neutral"}>
                        {document.status}
                      </Pill>
                    </div>
                    <p className="mt-2 text-sm leading-6 text-slate-600">
                      {document.description}
                    </p>
                  </div>
                ))}
              </div>
            </article>

            <article className="rounded-[28px] border border-slate-200 bg-white p-6">
              <h2 className="text-lg font-semibold text-slate-950">Map and access context</h2>
              <div className="mt-4 grid gap-4 lg:grid-cols-[1fr_0.9fr]">
                <div className="rounded-[24px] border border-slate-200 bg-[linear-gradient(135deg,#dbeafe_0%,#eef8ff_52%,#ffffff_100%)] p-4">
                  <p className="text-xs font-semibold uppercase tracking-[0.22em] text-sky-700">
                    Map placeholder
                  </p>
                  <p className="mt-2 text-sm leading-7 text-slate-600">
                    Exact map and boundary data are delivered through the provider adapter layer.
                    This page keeps the geographic slot and property context ready for map render,
                    walkability, school overlays, and similar-home search.
                  </p>
                  <div className="mt-5 grid grid-cols-5 gap-3">
                    {Array.from({ length: 15 }).map((_, index) => (
                      <div
                        className={`h-12 rounded-2xl ${
                          index === 7 ? "bg-sky-300/90" : "bg-white/80"
                        }`}
                        key={index}
                      />
                    ))}
                  </div>
                </div>

                <div className="space-y-3 rounded-[24px] border border-slate-200 bg-slate-50 p-4">
                  <p className="text-sm font-semibold text-slate-900">Risk and provenance</p>
                  {listing.risks.length > 0 ? (
                    listing.risks.map((risk) => (
                      <div className="rounded-2xl border border-slate-200 bg-white p-4" key={risk.key}>
                        <p className="font-medium text-slate-900">{risk.label}</p>
                        <p className="mt-1 text-sm text-slate-600">
                          {risk.status === "yes"
                            ? "Present"
                            : risk.status === "no"
                              ? "Not supplied as a concern"
                              : "Unknown"}
                          {" · "}
                          {risk.provenance.replaceAll("_", " ")}
                        </p>
                      </div>
                    ))
                  ) : (
                    <p className="text-sm leading-7 text-slate-600">
                      No additional risk metadata has been supplied yet. Buyers should still carry
                      out independent due diligence.
                    </p>
                  )}
                </div>
              </div>
            </article>
          </div>

          <div className="space-y-6">
            <article className="rounded-[28px] border border-slate-200 bg-white p-6">
              <h2 className="text-lg font-semibold text-slate-950">Comparable sales</h2>
              <div className="mt-4 space-y-3">
                {listing.comparableSales.length ? (
                  listing.comparableSales.map((sale) => (
                    <div
                      className="rounded-2xl border border-slate-200 p-4 text-sm text-slate-600"
                      key={sale.id}
                    >
                      <p className="font-semibold text-slate-900">{sale.address}</p>
                      <p>{sale.soldPrice ? `$${sale.soldPrice.toLocaleString()}` : "Price unavailable"}</p>
                      <p>Sold {sale.soldAt} · {sale.distanceKm} km away</p>
                    </div>
                  ))
                ) : (
                  <p className="text-sm text-slate-600">
                    Comparable sales will appear here when licensed enrichment data is available.
                  </p>
                )}
              </div>
            </article>
            <article className="rounded-[28px] border border-slate-200 bg-white p-6">
              <h2 className="text-lg font-semibold text-slate-950">Schools and amenities</h2>
              <div className="mt-4 space-y-3 text-sm text-slate-600">
                {listing.schools.map((school) => (
                  <p key={school.name}>{school.name} · {school.distanceKm} km</p>
                ))}
                {listing.amenities.map((amenity) => (
                  <p key={amenity.label}>{amenity.label} · {amenity.distanceKm} km</p>
                ))}
              </div>
            </article>
            <article className="rounded-[28px] border border-slate-200 bg-white p-6">
              <h2 className="text-lg font-semibold text-slate-950">Sale timeline</h2>
              <div className="mt-4 space-y-3">
                {listing.timelines.map((timeline) => (
                  <div className="flex items-center justify-between gap-4 text-sm" key={timeline.label}>
                    <span className="text-slate-600">{timeline.label}</span>
                    <span className="font-semibold text-slate-900">{timeline.value}</span>
                  </div>
                ))}
              </div>
            </article>
          </div>
        </section>
      </div>
      <div className="fixed inset-x-4 bottom-24 z-30 md:hidden">
        <div className="grid grid-cols-3 gap-2 rounded-[28px] border border-white/80 bg-white/92 p-2 shadow-lg shadow-slate-300/40 backdrop-blur">
          <Link
            className="rounded-[20px] bg-slate-900 px-3 py-3 text-center text-sm font-semibold text-white"
            href="/inspections"
          >
            Inspect
          </Link>
          <Link
            className="rounded-[20px] border border-slate-200 px-3 py-3 text-center text-sm font-semibold text-slate-900"
            href="/messages"
          >
            Ask owner
          </Link>
          <Link
            className="rounded-[20px] border border-teal-200 bg-teal-50 px-3 py-3 text-center text-sm font-semibold text-teal-900"
            href="/offers"
          >
            Make offer
          </Link>
        </div>
      </div>
    </AppShell>
  );
}
