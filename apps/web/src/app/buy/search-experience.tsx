"use client";

import Link from "next/link";
import {
  startTransition,
  useDeferredValue,
  useEffect,
  useMemo,
  useState,
} from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { listings, savedSearches } from "@homeowner/domain";
import {
  applyListingFilters,
  deserializeSearchFilters,
  serializeSearchFilters,
} from "@homeowner/search";
import type { AustralianState, PropertyType, SearchFilters } from "@homeowner/types";
import { Pill, PropertyCard, SectionHeading } from "@homeowner/ui";

const stateOptions: AustralianState[] = ["NSW", "VIC", "QLD", "SA", "ACT", "NT", "WA", "TAS"];

function filtersFromParams(searchParams: URLSearchParams): SearchFilters {
  const queryString = searchParams.toString();

  if (!queryString) {
    return {};
  }

  try {
    return deserializeSearchFilters(queryString);
  } catch {
    return {};
  }
}

export function SearchExperience() {
  const pathname = usePathname();
  const router = useRouter();
  const searchParams = useSearchParams();
  const [filters, setFilters] = useState<SearchFilters>(() => filtersFromParams(searchParams));
  const deferredQuery = useDeferredValue(filters.query);

  useEffect(() => {
    setFilters(filtersFromParams(searchParams));
  }, [searchParams]);

  const effectiveFilters = useMemo(
    () => ({
      ...filters,
      query: deferredQuery,
    }),
    [deferredQuery, filters],
  );

  const filteredListings = applyListingFilters(listings, effectiveFilters);
  const activePills = buildActiveFilterPills(filters);

  function commitFilters(nextFilters: SearchFilters) {
    setFilters(nextFilters);

    const query = serializeSearchFilters(nextFilters);
    const target = query ? `${pathname}?${query}` : pathname;

    startTransition(() => {
      router.replace(target, { scroll: false });
    });
  }

  function updateFilter<K extends keyof SearchFilters>(key: K, value: SearchFilters[K]) {
    commitFilters({
      ...filters,
      [key]: value,
    });
  }

  function updateBooleanFilter<K extends keyof SearchFilters>(key: K, enabled: boolean) {
    commitFilters({
      ...filters,
      [key]: enabled ? true : undefined,
    });
  }

  function clearFilters() {
    commitFilters({});
  }

  return (
    <div className="space-y-10">
      <SectionHeading
        eyebrow="Search"
        title="Map-ready buyer search that stays calm, fast, and trustworthy"
        description="Filters persist in the URL, disclosure status stays visible, and each listing pushes one clear next step: save it, book an inspection, ask the owner, or make a non-binding offer."
      />

      <section className="grid gap-8 lg:grid-cols-[360px_1fr]">
        <aside className="space-y-6 rounded-[30px] border border-slate-200 bg-white p-6 shadow-sm shadow-slate-200/50">
          <div className="space-y-2">
            <p className="text-xs font-semibold uppercase tracking-[0.22em] text-sky-700">
              Buyer filters
            </p>
            <h3 className="text-2xl font-semibold tracking-tight text-slate-950">
              Keep it simple first
            </h3>
            <p className="text-sm leading-7 text-slate-600">
              Use a few strong filters, then let disclosure status and direct-owner trust signals
              do the rest.
            </p>
          </div>

          <div className="space-y-4">
            <Field label="Search suburb, postcode, or keyword">
              <input
                className={inputClassName}
                onChange={(event) => updateFilter("query", event.target.value || undefined)}
                placeholder="Paddington, terrace, pool"
                value={filters.query ?? ""}
              />
            </Field>

            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-1">
              <Field label="State / territory">
                <select
                  className={inputClassName}
                  onChange={(event) =>
                    updateFilter(
                      "state",
                      event.target.value ? (event.target.value as AustralianState) : undefined,
                    )
                  }
                  value={filters.state ?? ""}
                >
                  <option value="">All Australia</option>
                  {stateOptions.map((state) => (
                    <option key={state} value={state}>
                      {state}
                    </option>
                  ))}
                </select>
              </Field>

              <Field label="Sort">
                <select
                  className={inputClassName}
                  onChange={(event) =>
                    updateFilter(
                      "sort",
                      event.target.value
                        ? (event.target.value as SearchFilters["sort"])
                        : undefined,
                    )
                  }
                  value={filters.sort ?? ""}
                >
                  <option value="">Newest</option>
                  <option value="price_asc">Price: low to high</option>
                  <option value="price_desc">Price: high to low</option>
                  <option value="land_desc">Land size</option>
                </select>
              </Field>
            </div>

            <div className="grid gap-4 sm:grid-cols-2">
              <Field label="Minimum price">
                <input
                  className={inputClassName}
                  inputMode="numeric"
                  onChange={(event) =>
                    updateFilter("minPrice", parseOptionalNumber(event.target.value))
                  }
                  placeholder="800000"
                  value={filters.minPrice?.toString() ?? ""}
                />
              </Field>
              <Field label="Maximum price">
                <input
                  className={inputClassName}
                  inputMode="numeric"
                  onChange={(event) =>
                    updateFilter("maxPrice", parseOptionalNumber(event.target.value))
                  }
                  placeholder="2500000"
                  value={filters.maxPrice?.toString() ?? ""}
                />
              </Field>
            </div>

            <div className="grid gap-4 sm:grid-cols-2">
              <Field label="Bedrooms">
                <select
                  className={inputClassName}
                  onChange={(event) =>
                    updateFilter("minBedrooms", parseOptionalNumber(event.target.value))
                  }
                  value={filters.minBedrooms?.toString() ?? ""}
                >
                  <option value="">Any</option>
                  {[1, 2, 3, 4, 5].map((count) => (
                    <option key={count} value={count}>
                      {count}+
                    </option>
                  ))}
                </select>
              </Field>
              <Field label="Property type">
                <select
                  className={inputClassName}
                  onChange={(event) =>
                    updateFilter(
                      "propertyTypes",
                      event.target.value
                        ? [event.target.value as PropertyType]
                        : undefined,
                    )
                  }
                  value={filters.propertyTypes?.[0] ?? ""}
                >
                  <option value="">Any type</option>
                  <option value="house">House</option>
                  <option value="townhouse">Townhouse</option>
                  <option value="apartment">Apartment / Unit</option>
                  <option value="land">Land</option>
                  <option value="acreage">Acreage</option>
                  <option value="strata_home">Strata home</option>
                </select>
              </Field>
            </div>
          </div>

          <details className="rounded-[24px] border border-slate-200 bg-slate-50 p-4">
            <summary className="cursor-pointer text-sm font-semibold text-slate-900">
              Advanced filters
            </summary>
            <div className="mt-4 grid gap-3">
              <CheckboxCard
                checked={Boolean(filters.sellerVerified)}
                copy="Seller verified"
                onChange={(checked) => updateBooleanFilter("sellerVerified", checked)}
              />
              <CheckboxCard
                checked={Boolean(filters.hasDocuments)}
                copy="Documents ready"
                onChange={(checked) => updateBooleanFilter("hasDocuments", checked)}
              />
              <CheckboxCard
                checked={Boolean(filters.openHomeOnly)}
                copy="Open home available"
                onChange={(checked) => updateBooleanFilter("openHomeOnly", checked)}
              />
              <CheckboxCard
                checked={Boolean(filters.pool)}
                copy="Pool"
                onChange={(checked) => updateBooleanFilter("pool", checked)}
              />
              <CheckboxCard
                checked={Boolean(filters.study)}
                copy="Study"
                onChange={(checked) => updateBooleanFilter("study", checked)}
              />
              <CheckboxCard
                checked={Boolean(filters.includeUnderOffer)}
                copy="Include under-offer listings"
                onChange={(checked) => updateBooleanFilter("includeUnderOffer", checked)}
              />
            </div>
          </details>

          <div className="flex flex-wrap gap-3">
            <button
              className="rounded-full border border-slate-300 px-4 py-2 text-sm font-semibold text-slate-700 transition hover:border-slate-400"
              onClick={clearFilters}
              type="button"
            >
              Clear filters
            </button>
            <Link
              className="rounded-full bg-slate-950 px-4 py-2 text-sm font-semibold text-white transition hover:bg-slate-800"
              href="/saved"
            >
              View saved properties
            </Link>
          </div>
        </aside>

        <div className="space-y-6">
          <div className="rounded-[30px] border border-slate-200 bg-[linear-gradient(135deg,#dbeafe_0%,#ecfeff_48%,#f8fafc_100%)] p-6">
            <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
              <div className="space-y-2">
                <p className="text-xs font-semibold uppercase tracking-[0.22em] text-sky-700">
                  Live search
                </p>
                <h3 className="text-2xl font-semibold tracking-tight text-slate-950">
                  {filteredListings.length} homes match right now
                </h3>
                <p className="max-w-2xl text-sm leading-7 text-slate-600">
                  Search stays anchored to the current map viewport once a real map adapter is
                  enabled. The current slice keeps the URL stable so saved searches and alerts can
                  graduate cleanly into API-backed persistence.
                </p>
              </div>
              <div className="rounded-2xl border border-sky-200 bg-white/80 px-4 py-3 text-sm text-slate-700">
                {activePills.length > 0 ? `${activePills.length} active filters` : "No filters applied"}
              </div>
            </div>

            <div className="mt-5 flex flex-wrap gap-2">
              {activePills.length > 0 ? (
                activePills.map((pill) => (
                  <Pill key={pill} tone="neutral">
                    {pill}
                  </Pill>
                ))
              ) : (
                <Pill tone="accent">Ready for saved search alerts</Pill>
              )}
            </div>

            <div className="mt-6 rounded-[28px] border border-white/70 bg-white/65 p-4">
              <div className="flex items-center justify-between gap-4">
                <div>
                  <p className="text-xs font-semibold uppercase tracking-[0.22em] text-sky-700">
                    Map preview
                  </p>
                  <p className="mt-2 text-sm text-slate-600">
                    Polygon search, clustering, and current bounds queries are architected into the
                    search layer and ready for a map provider adapter.
                  </p>
                </div>
                <Pill tone="accent">Viewport search ready</Pill>
              </div>
              <div className="mt-5 grid grid-cols-6 gap-3">
                {Array.from({ length: 18 }).map((_, index) => (
                  <div
                    className={`h-16 rounded-2xl ${
                      index % 5 === 0 ? "bg-sky-300/80" : "bg-white/70"
                    }`}
                    key={index}
                  />
                ))}
              </div>
            </div>
          </div>

          <div className="grid gap-6 md:grid-cols-[1fr_auto] md:items-start">
            <article className="rounded-[28px] border border-slate-200 bg-white p-5">
              <p className="text-xs font-semibold uppercase tracking-[0.22em] text-sky-700">
                Saved search example
              </p>
              <div className="mt-3 flex flex-wrap gap-3">
                {savedSearches.map((search) => (
                  <div
                    className="rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3"
                    key={search.id}
                  >
                    <p className="font-semibold text-slate-950">{search.name}</p>
                    <p className="mt-1 text-sm text-slate-600">
                      Instant alerts {search.instantAlert ? "enabled" : "paused"}
                    </p>
                  </div>
                ))}
              </div>
            </article>
            <Link
              className="rounded-full border border-slate-300 bg-white px-5 py-3 text-sm font-semibold text-slate-900 transition hover:border-slate-400"
              href="/profile"
            >
              Manage alerts
            </Link>
          </div>

          {filteredListings.length > 0 ? (
            <div className="grid gap-6 xl:grid-cols-2">
              {filteredListings.map((listing) => (
                <Link href={`/property/${listing.slug}`} key={listing.id}>
                  <PropertyCard listing={listing} />
                </Link>
              ))}
            </div>
          ) : (
            <article className="rounded-[30px] border border-dashed border-slate-300 bg-white/80 p-8 text-center">
              <h3 className="text-2xl font-semibold tracking-tight text-slate-950">
                No homes match these filters yet
              </h3>
              <p className="mt-3 text-sm leading-7 text-slate-600">
                Broaden one or two filters, or save this search so the platform can alert you when
                a matching owner-led listing lands.
              </p>
            </article>
          )}
        </div>
      </section>
    </div>
  );
}

function Field(props: { label: string; children: React.ReactNode }) {
  return (
    <label className="block space-y-2">
      <span className="text-sm font-semibold text-slate-800">{props.label}</span>
      {props.children}
    </label>
  );
}

function CheckboxCard(props: {
  checked: boolean;
  copy: string;
  onChange: (checked: boolean) => void;
}) {
  return (
    <label className="flex items-start gap-3 rounded-2xl border border-slate-200 bg-white px-4 py-3 text-sm text-slate-700">
      <input
        checked={props.checked}
        className="mt-1 size-4"
        onChange={(event) => props.onChange(event.target.checked)}
        type="checkbox"
      />
      <span>{props.copy}</span>
    </label>
  );
}

function buildActiveFilterPills(filters: SearchFilters): string[] {
  const pills: string[] = [];

  if (filters.query) pills.push(`Keyword: ${filters.query}`);
  if (filters.state) pills.push(filters.state);
  if (filters.propertyTypes?.[0]) pills.push(filters.propertyTypes[0].replaceAll("_", " "));
  if (filters.minPrice) pills.push(`From $${filters.minPrice.toLocaleString()}`);
  if (filters.maxPrice) pills.push(`To $${filters.maxPrice.toLocaleString()}`);
  if (filters.minBedrooms) pills.push(`${filters.minBedrooms}+ beds`);
  if (filters.sellerVerified) pills.push("Seller verified");
  if (filters.hasDocuments) pills.push("Documents ready");
  if (filters.openHomeOnly) pills.push("Open home");
  if (filters.pool) pills.push("Pool");
  if (filters.study) pills.push("Study");
  if (filters.includeUnderOffer) pills.push("Includes under offer");

  return pills;
}

function parseOptionalNumber(value: string): number | undefined {
  if (!value.trim()) {
    return undefined;
  }

  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
}

const inputClassName =
  "w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 text-sm text-slate-900 outline-none transition focus:border-sky-400 focus:ring-4 focus:ring-sky-100";
