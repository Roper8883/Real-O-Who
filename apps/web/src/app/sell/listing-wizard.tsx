"use client";

import { useEffect, useMemo, useState } from "react";
import {
  calculateLaunchScore,
  getJurisdictionSnapshot,
  isReadyToPublish,
  labelForListingMode,
  publishBlockers,
  type ListingMode,
  type ListingWizardDraft,
  type PropertyType,
  type StateCode,
} from "./listing-wizard.logic";

const storageKey = "homeowner.sell.wizard.v1";

const initialDraft: ListingWizardDraft = {
  addressLine: "",
  suburb: "",
  postcode: "",
  state: "NSW",
  propertyType: "house",
  bedrooms: "3",
  bathrooms: "2",
  parking: "1",
  landSize: "",
  buildingSize: "",
  askingPrice: "",
  priceStrategy: "Private treaty with offers invited after inspections",
  listingMode: "public",
  headline: "",
  description: "",
  ownerLoves: "",
  mediaLinks: "",
  floorplanLink: "",
  inspectionTimes: "",
  legalRepresentative: "",
  sellerAuthorityConfirmed: false,
  contractReadyConfirmed: false,
  disclosureNotes: "",
};

const steps = [
  { id: "address", label: "Address" },
  { id: "facts", label: "Facts" },
  { id: "pricing", label: "Pricing" },
  { id: "media", label: "Media" },
  { id: "description", label: "Description" },
  { id: "schedule", label: "Schedule" },
  { id: "disclosures", label: "Disclosures" },
  { id: "preview", label: "Preview" },
] as const;

export function ListingWizard() {
  const [draft, setDraft] = useState<ListingWizardDraft>(initialDraft);
  const [currentStepIndex, setCurrentStepIndex] = useState(0);
  const [hydrated, setHydrated] = useState(false);
  const [lastSavedAt, setLastSavedAt] = useState<string | null>(null);
  const [publishMessage, setPublishMessage] = useState<string | null>(null);

  useEffect(() => {
    const saved = window.localStorage.getItem(storageKey);

    if (saved) {
      try {
        const parsed = JSON.parse(saved) as ListingWizardDraft;
        // Local draft recovery is an external-store sync, so restoring here is intentional.
        // eslint-disable-next-line react-hooks/set-state-in-effect
        setDraft({ ...initialDraft, ...parsed });
      } catch {
        window.localStorage.removeItem(storageKey);
      }
    }

    setHydrated(true);
  }, []);

  useEffect(() => {
    if (!hydrated) {
      return;
    }

    window.localStorage.setItem(storageKey, JSON.stringify(draft));
  }, [draft, hydrated]);

  const completion = useMemo(() => {
    const completedSteps = [
      Boolean(draft.addressLine && draft.suburb && draft.postcode),
      Boolean(draft.bedrooms && draft.bathrooms && draft.propertyType),
      Boolean(draft.askingPrice && draft.priceStrategy),
      Boolean(draft.mediaLinks),
      Boolean(draft.headline && draft.description),
      Boolean(draft.inspectionTimes),
      Boolean(draft.sellerAuthorityConfirmed && draft.contractReadyConfirmed),
      isReadyToPublish(draft),
    ];

    return {
      completedSteps,
      percent: Math.round((completedSteps.filter(Boolean).length / completedSteps.length) * 100),
    };
  }, [draft]);

  const blockers = publishBlockers(draft);
  const launchScore = calculateLaunchScore(draft);
  const jurisdiction = useMemo(() => getJurisdictionSnapshot(draft.state), [draft.state]);
  const currentStep = steps[currentStepIndex];

  function updateDraft<K extends keyof ListingWizardDraft>(key: K, value: ListingWizardDraft[K]) {
    setDraft((current) => ({ ...current, [key]: value }));
    setLastSavedAt(new Date().toLocaleTimeString([], { hour: "numeric", minute: "2-digit" }));
  }

  function goToStep(index: number) {
    setCurrentStepIndex(index);
    setPublishMessage(null);
  }

  function handlePublish() {
    if (!isReadyToPublish(draft)) {
      setPublishMessage("This listing still needs the required seller authority and contract/disclosure confirmations before publish.");
      return;
    }

    setDraft((current) => ({
      ...current,
      lastPublishedAt: new Date().toISOString(),
    }));
    setLastSavedAt(new Date().toLocaleTimeString([], { hour: "numeric", minute: "2-digit" }));
    setPublishMessage("Listing marked ready for publish. In production, this step would trigger moderation, indexing, and public availability.");
  }

  return (
    <div className="grid gap-8 xl:grid-cols-[1.1fr_0.9fr]">
      <section className="space-y-6 rounded-[32px] border border-slate-200 bg-white p-6 shadow-sm shadow-slate-200/50">
        <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <div className="space-y-2">
            <p className="text-xs font-semibold uppercase tracking-[0.24em] text-teal-700">
              Fast listing wizard
            </p>
            <h2 className="text-2xl font-semibold tracking-tight text-slate-950">
              Build a trustworthy listing in minutes
            </h2>
            <p className="max-w-2xl text-sm leading-7 text-slate-600">
              The flow stays intentionally simple up front, then opens the extra disclosure and workflow detail only when it matters.
            </p>
          </div>
          <div className="rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-600">
            Autosave {lastSavedAt ? `at ${lastSavedAt}` : "enabled"}
          </div>
        </div>

        <div className="space-y-3">
          <div className="flex items-center justify-between text-sm">
            <span className="font-medium text-slate-700">Progress</span>
            <span className="text-slate-500">{completion.percent}% complete</span>
          </div>
          <div
            aria-label="Listing wizard progress"
            aria-valuemax={100}
            aria-valuemin={0}
            aria-valuenow={completion.percent}
            className="h-3 overflow-hidden rounded-full bg-slate-100"
            role="progressbar"
          >
            <div
              className="h-full rounded-full bg-[linear-gradient(90deg,#0f766e_0%,#0891b2_100%)] transition-[width]"
              style={{ width: `${completion.percent}%` }}
            />
          </div>
        </div>

        <div className="grid gap-2 sm:grid-cols-4">
          {steps.map((step, index) => {
            const isActive = currentStepIndex == index;
            const isComplete = completion.completedSteps[index];

            return (
              <button
                className={`rounded-2xl border px-4 py-3 text-left text-sm transition ${
                  isActive
                    ? "border-slate-900 bg-slate-900 text-white"
                    : isComplete
                      ? "border-teal-200 bg-teal-50 text-teal-900"
                      : "border-slate-200 bg-white text-slate-600 hover:border-slate-300"
                }`}
                key={step.id}
                onClick={() => goToStep(index)}
                type="button"
              >
                <div className="font-semibold">{step.label}</div>
                <div className="mt-1 text-xs opacity-80">
                  {isComplete ? "Ready" : index < currentStepIndex ? "Visited" : "Next"}
                </div>
              </button>
            );
          })}
        </div>

        <div className="rounded-[28px] border border-slate-200 bg-slate-50 p-5">
          {currentStep.id === "address" && (
            <div className="grid gap-4 md:grid-cols-2">
              <Field label="Street address" required>
                <input
                  className={inputClassName}
                  onChange={(event) => updateDraft("addressLine", event.target.value)}
                  placeholder="16 Windsor Street"
                  value={draft.addressLine}
                />
              </Field>
              <Field label="Suburb" required>
                <input
                  className={inputClassName}
                  onChange={(event) => updateDraft("suburb", event.target.value)}
                  placeholder="Paddington"
                  value={draft.suburb}
                />
              </Field>
              <Field label="Postcode" required>
                <input
                  className={inputClassName}
                  inputMode="numeric"
                  onChange={(event) => updateDraft("postcode", event.target.value)}
                  placeholder="2021"
                  value={draft.postcode}
                />
              </Field>
              <Field label="State / territory" required>
                <select
                  className={inputClassName}
                  onChange={(event) => updateDraft("state", event.target.value as StateCode)}
                  value={draft.state}
                >
                  {["NSW", "VIC", "QLD", "SA", "ACT", "NT", "WA", "TAS"].map((state) => (
                    <option key={state} value={state}>
                      {state}
                    </option>
                  ))}
                </select>
              </Field>
            </div>
          )}

          {currentStep.id === "facts" && (
            <div className="space-y-4">
              <div className="grid gap-4 md:grid-cols-2">
                <Field label="Property type" required>
                  <select
                    className={inputClassName}
                    onChange={(event) => updateDraft("propertyType", event.target.value as PropertyType)}
                    value={draft.propertyType}
                  >
                    <option value="house">House</option>
                    <option value="townhouse">Townhouse</option>
                    <option value="apartment">Apartment / Unit</option>
                    <option value="land">Land</option>
                    <option value="acreage">Acreage / Lifestyle</option>
                  </select>
                </Field>
                <Field label="Bedrooms" required>
                  <input
                    className={inputClassName}
                    inputMode="numeric"
                    onChange={(event) => updateDraft("bedrooms", event.target.value)}
                    value={draft.bedrooms}
                  />
                </Field>
                <Field label="Bathrooms" required>
                  <input
                    className={inputClassName}
                    inputMode="numeric"
                    onChange={(event) => updateDraft("bathrooms", event.target.value)}
                    value={draft.bathrooms}
                  />
                </Field>
                <Field label="Parking">
                  <input
                    className={inputClassName}
                    inputMode="numeric"
                    onChange={(event) => updateDraft("parking", event.target.value)}
                    value={draft.parking}
                  />
                </Field>
              </div>

              <details className="rounded-2xl border border-slate-200 bg-white p-4">
                <summary className="cursor-pointer text-sm font-semibold text-slate-900">
                  Advanced property details
                </summary>
                <div className="mt-4 grid gap-4 md:grid-cols-2">
                  <Field label="Land size">
                    <input
                      className={inputClassName}
                      onChange={(event) => updateDraft("landSize", event.target.value)}
                      placeholder="612 sqm"
                      value={draft.landSize}
                    />
                  </Field>
                  <Field label="Building size">
                    <input
                      className={inputClassName}
                      onChange={(event) => updateDraft("buildingSize", event.target.value)}
                      placeholder="284 sqm"
                      value={draft.buildingSize}
                    />
                  </Field>
                </div>
              </details>
            </div>
          )}

          {currentStep.id === "pricing" && (
            <div className="grid gap-4 md:grid-cols-2">
              <Field label="Price guide" required>
                <input
                  className={inputClassName}
                  onChange={(event) => updateDraft("askingPrice", event.target.value)}
                  placeholder="$1.98m"
                  value={draft.askingPrice}
                />
              </Field>
              <Field label="Listing mode" required>
                <select
                  className={inputClassName}
                  onChange={(event) => updateDraft("listingMode", event.target.value as ListingMode)}
                  value={draft.listingMode}
                >
                  <option value="public">Public</option>
                  <option value="off_market">Off-market</option>
                  <option value="invite_only">Invite only</option>
                  <option value="password_protected">Password-protected data room</option>
                  <option value="coming_soon">Coming soon</option>
                </select>
              </Field>
              <div className="md:col-span-2">
                <Field label="Seller pricing guidance" required>
                  <textarea
                    className={textareaClassName}
                    onChange={(event) => updateDraft("priceStrategy", event.target.value)}
                    placeholder="Explain the pricing posture and when you want the platform to encourage offers."
                    value={draft.priceStrategy}
                  />
                </Field>
              </div>
            </div>
          )}

          {currentStep.id === "media" && (
            <div className="space-y-4">
              <Field
                description="For now this vertical slice accepts media manifests and URLs. The storage adapter and signed upload pipeline are already wired at the repo foundation level."
                label="Photo / video links"
                required
              >
                <textarea
                  className={textareaClassName}
                  onChange={(event) => updateDraft("mediaLinks", event.target.value)}
                  placeholder={"https://.../front.jpg\nhttps://.../kitchen.jpg\nhttps://.../walkthrough.mp4"}
                  value={draft.mediaLinks}
                />
              </Field>
              <Field label="Floor plan link">
                <input
                  className={inputClassName}
                  onChange={(event) => updateDraft("floorplanLink", event.target.value)}
                  placeholder="https://.../floorplan.pdf"
                  value={draft.floorplanLink}
                />
              </Field>
            </div>
          )}

          {currentStep.id === "description" && (
            <div className="space-y-4">
              <Field label="Headline" required>
                <input
                  className={inputClassName}
                  maxLength={90}
                  onChange={(event) => updateDraft("headline", event.target.value)}
                  placeholder="Renovated terrace with north-facing courtyard"
                  value={draft.headline}
                />
              </Field>
              <Field label="Property description" required>
                <textarea
                  className={textareaClassName}
                  onChange={(event) => updateDraft("description", event.target.value)}
                  placeholder="Explain the home simply, honestly, and clearly."
                  value={draft.description}
                />
              </Field>
              <Field label="What the owner loves">
                <textarea
                  className={textareaClassName}
                  onChange={(event) => updateDraft("ownerLoves", event.target.value)}
                  placeholder="Morning light in the living room, the quiet street, and the walk to cafes."
                  value={draft.ownerLoves}
                />
              </Field>
            </div>
          )}

          {currentStep.id === "schedule" && (
            <div className="space-y-4">
              <Field
                description="Use one line per slot, for example: Sat 10:30am open home or Tue 5:45pm private inspection."
                label="Inspection schedule"
                required
              >
                <textarea
                  className={textareaClassName}
                  onChange={(event) => updateDraft("inspectionTimes", event.target.value)}
                  placeholder={"Sat 10:30am open home\nTue 5:45pm private inspection"}
                  value={draft.inspectionTimes}
                />
              </Field>
              <Field label="Legal representative / conveyancer">
                <input
                  className={inputClassName}
                  onChange={(event) => updateDraft("legalRepresentative", event.target.value)}
                  placeholder="Lumen Legal"
                  value={draft.legalRepresentative}
                />
              </Field>
            </div>
          )}

          {currentStep.id === "disclosures" && (
            <div className="space-y-4">
              <div className="rounded-[26px] border border-sky-200 bg-sky-50 p-4">
                <p className="text-xs font-semibold uppercase tracking-[0.22em] text-sky-700">
                  {draft.state} requirements
                </p>
                <p className="mt-2 text-sm leading-7 text-slate-700">
                  {jurisdiction.ruleSet.disclosureSummary}
                </p>
                <ul className="mt-4 space-y-2 text-sm text-slate-700">
                  {jurisdiction.ruleSet.publishingPrerequisites.map((item) => (
                    <li key={item}>• {item}</li>
                  ))}
                </ul>
              </div>

              <label className={checkboxCardClassName}>
                <input
                  checked={draft.sellerAuthorityConfirmed}
                  className="mt-1 size-4"
                  onChange={(event) => updateDraft("sellerAuthorityConfirmed", event.target.checked)}
                  type="checkbox"
                />
                <div>
                  <p className="font-semibold text-slate-900">I have authority to market this property</p>
                  <p className="mt-1 text-sm leading-6 text-slate-600">
                    Required before publish in every market. This platform is not verifying legal authority automatically in this slice.
                  </p>
                </div>
              </label>

              <label className={checkboxCardClassName}>
                <input
                  checked={draft.contractReadyConfirmed}
                  className="mt-1 size-4"
                  onChange={(event) => updateDraft("contractReadyConfirmed", event.target.checked)}
                  type="checkbox"
                />
                <div>
                  <p className="font-semibold text-slate-900">Core contract / disclosure pack is ready or being handled correctly for {draft.state}</p>
                  <p className="mt-1 text-sm leading-6 text-slate-600">
                    The platform will not present this as legal certainty. Buyers must still obtain independent advice.
                  </p>
                </div>
              </label>

              <Field label="Disclosure notes">
                <textarea
                  className={textareaClassName}
                  onChange={(event) => updateDraft("disclosureNotes", event.target.value)}
                  placeholder="Add contract readiness, disclosure bundle notes, strata information, or other trust-building details."
                  value={draft.disclosureNotes}
                />
              </Field>
            </div>
          )}

          {currentStep.id === "preview" && (
            <div className="space-y-5">
              <div className="rounded-[26px] border border-slate-200 bg-white p-5">
                <p className="text-xs font-semibold uppercase tracking-[0.24em] text-teal-700">
                  Public preview
                </p>
                <h3 className="mt-3 text-2xl font-semibold tracking-tight text-slate-950">
                  {draft.headline || "Your listing headline will appear here"}
                </h3>
                <p className="mt-2 text-sm text-slate-500">
                  {[draft.addressLine, draft.suburb, draft.state, draft.postcode].filter(Boolean).join(", ") || "Address pending"}
                </p>
                <p className="mt-5 text-sm leading-7 text-slate-600">
                  {draft.description || "Description preview will update as soon as you add seller copy."}
                </p>
              </div>

              <div className="rounded-[26px] border border-amber-200 bg-amber-50 p-5">
                <p className="font-semibold text-slate-900">Publish blockers</p>
                <ul className="mt-3 space-y-2 text-sm text-slate-700">
                  {blockers.length > 0 ? (
                    blockers.map((blocker) => <li key={blocker}>• {blocker}</li>)
                  ) : (
                    <li>• No blockers detected for this vertical slice.</li>
                  )}
                </ul>
              </div>
            </div>
          )}
        </div>

        {publishMessage ? (
          <div className="rounded-2xl border border-teal-200 bg-teal-50 px-4 py-3 text-sm text-teal-900">
            {publishMessage}
          </div>
        ) : null}

        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <button
            className="rounded-full border border-slate-300 px-5 py-3 text-sm font-semibold text-slate-700 transition hover:border-slate-400 disabled:cursor-not-allowed disabled:opacity-40"
            disabled={currentStepIndex === 0}
            onClick={() => setCurrentStepIndex((current) => Math.max(0, current - 1))}
            type="button"
          >
            Back
          </button>
          <div className="flex flex-wrap gap-3">
            {currentStepIndex < steps.length - 1 ? (
              <button
                className="rounded-full bg-slate-950 px-5 py-3 text-sm font-semibold text-white transition hover:bg-slate-800"
                onClick={() =>
                  setCurrentStepIndex((current) => Math.min(steps.length - 1, current + 1))
                }
                type="button"
              >
                Continue
              </button>
            ) : (
              <button
                className="rounded-full bg-teal-700 px-5 py-3 text-sm font-semibold text-white transition hover:bg-teal-800"
                onClick={handlePublish}
                type="button"
              >
                Mark ready to publish
              </button>
            )}
          </div>
        </div>
      </section>

      <aside className="space-y-6">
        <div className="rounded-[32px] border border-slate-200 bg-white p-6 shadow-sm shadow-slate-200/50">
          <p className="text-xs font-semibold uppercase tracking-[0.24em] text-sky-700">
            Seller trust summary
          </p>
          <div className="mt-4 space-y-4">
            <PreviewMetric label="Launch score" value={`${launchScore}/100`} />
            <PreviewMetric label="Listing mode" value={labelForListingMode(draft.listingMode)} />
            <PreviewMetric label="Price guide" value={draft.askingPrice || "Pending"} />
            <PreviewMetric
              label="Inspection slots"
              value={draft.inspectionTimes ? draft.inspectionTimes.split("\n").filter(Boolean).length.toString() : "0"}
            />
            <PreviewMetric
              label="Disclosure readiness"
              value={draft.sellerAuthorityConfirmed && draft.contractReadyConfirmed ? "Ready" : "Needs attention"}
            />
          </div>
        </div>

        <div className="rounded-[32px] border border-slate-200 bg-white p-6 shadow-sm shadow-slate-200/50">
          <p className="text-xs font-semibold uppercase tracking-[0.24em] text-sky-700">
            Jurisdiction layer
          </p>
          <div className="mt-4 space-y-4">
            <div className="rounded-2xl border border-slate-200 bg-slate-50 px-4 py-4">
              <p className="text-sm font-semibold text-slate-900">
                Cooling-off and workflow note
              </p>
              <p className="mt-2 text-sm leading-6 text-slate-600">
                {jurisdiction.ruleSet.coolingOff.note}
              </p>
            </div>

            <div className="rounded-2xl border border-slate-200 bg-slate-50 px-4 py-4">
              <p className="text-sm font-semibold text-slate-900">Required documents</p>
              <div className="mt-3 space-y-2">
                {jurisdiction.requiredDocuments.slice(0, 4).map((document) => (
                  <div className="flex items-start justify-between gap-4 text-sm" key={document.key}>
                    <span className="text-slate-700">{document.title}</span>
                    <span className="rounded-full bg-white px-3 py-1 text-xs font-semibold text-slate-600">
                      {document.status}
                    </span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>

        <div className="rounded-[32px] border border-slate-200 bg-slate-950 p-6 text-white shadow-sm shadow-slate-300/20">
          <p className="text-xs font-semibold uppercase tracking-[0.24em] text-teal-300">
            Keep it trustworthy
          </p>
          <div className="mt-4 space-y-3 text-sm leading-7 text-slate-200">
            <p>Use plain language and avoid exaggerated claims.</p>
            <p>Do not imply the platform provides legal advice or holds trust funds.</p>
            <p>Share only the facts you can stand behind, then let the document pack do the heavy lifting.</p>
          </div>
          <div className="mt-5 space-y-2 rounded-2xl border border-white/10 bg-white/5 p-4 text-sm leading-6 text-slate-200">
            {jurisdiction.offerWarnings.slice(0, 2).map((warning) => (
              <p key={warning}>{warning}</p>
            ))}
          </div>
        </div>
      </aside>
    </div>
  );
}

function Field(props: {
  label: string;
  required?: boolean;
  description?: string;
  children: React.ReactNode;
}) {
  return (
    <label className="block space-y-2">
      <div className="flex items-center gap-2 text-sm font-semibold text-slate-800">
        <span>{props.label}</span>
        {props.required ? <span className="text-teal-700">*</span> : null}
      </div>
      {props.description ? <p className="text-xs leading-6 text-slate-500">{props.description}</p> : null}
      {props.children}
    </label>
  );
}

function PreviewMetric(props: { label: string; value: string }) {
  return (
    <div className="rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3">
      <p className="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">{props.label}</p>
      <p className="mt-2 text-lg font-semibold tracking-tight text-slate-950">{props.value}</p>
    </div>
  );
}

const inputClassName =
  "w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 text-sm text-slate-900 outline-none transition placeholder:text-slate-400 focus:border-teal-500 focus:ring-4 focus:ring-teal-100";

const textareaClassName =
  "min-h-32 w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 text-sm text-slate-900 outline-none transition placeholder:text-slate-400 focus:border-teal-500 focus:ring-4 focus:ring-teal-100";

const checkboxCardClassName =
  "flex gap-4 rounded-2xl border border-slate-200 bg-white p-4";
