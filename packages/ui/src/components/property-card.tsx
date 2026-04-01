import type { ListingSummary } from "@homeowner/types";
import { Pill } from "./pill";

interface PropertyCardProps {
  listing: ListingSummary;
}

export function PropertyCard({ listing }: PropertyCardProps) {
  return (
    <article className="overflow-hidden rounded-[32px] border border-slate-200 bg-white shadow-sm shadow-slate-200/60">
      <div className="aspect-[4/3] overflow-hidden bg-slate-100">
        <img
          alt={listing.title}
          className="h-full w-full object-cover"
          src={listing.coverImage}
        />
      </div>
      <div className="space-y-4 p-5">
        <div className="flex flex-wrap gap-2">
          <Pill tone={listing.sellerVerified ? "success" : "neutral"}>
            {listing.sellerVerified ? "Seller verified" : "Seller pending"}
          </Pill>
          <Pill tone={listing.status === "under_offer" ? "warning" : "accent"}>
            {listing.status.replaceAll("_", " ")}
          </Pill>
        </div>
        <div className="space-y-1">
          <h3 className="text-xl font-semibold tracking-tight text-slate-950">
            {listing.priceLabel}
          </h3>
          <p className="text-lg font-medium text-slate-900">{listing.title}</p>
          <p className="text-sm text-slate-600">
            {listing.address.line1}, {listing.address.suburb} {listing.address.state}
          </p>
        </div>
        <div className="flex flex-wrap gap-4 text-sm text-slate-600">
          <span>{listing.facts.bedrooms} bed</span>
          <span>{listing.facts.bathrooms} bath</span>
          <span>{listing.facts.carSpaces} car</span>
          {listing.facts.landSizeSqm ? <span>{listing.facts.landSizeSqm} sqm</span> : null}
        </div>
      </div>
    </article>
  );
}
