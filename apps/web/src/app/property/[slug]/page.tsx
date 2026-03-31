import Image from "next/image";
import Link from "next/link";
import { listings } from "@homeowner/domain";
import { AppShell, Pill, SectionHeading } from "@homeowner/ui";

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

  return (
    <AppShell
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
          </div>
        </section>
      </div>
    </AppShell>
  );
}
