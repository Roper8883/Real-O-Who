import Link from "next/link";
import { buyers, savedProperties, savedSearches } from "@homeowner/domain";
import { AppShell, Pill, SectionHeading } from "@homeowner/ui";

export default function ProfilePage() {
  const buyer = buyers[0];

  return (
    <AppShell
      nav={
        <>
          <Link href="/">Home</Link>
          <Link href="/saved">Saved</Link>
          <Link href="/profile">Profile</Link>
        </>
      }
    >
      <div className="space-y-8">
        <SectionHeading
          eyebrow="Profile"
          title={buyer.displayName}
          description="Security settings, saved searches, notifications, and role-aware workflows sit in one account surface for buyers, sellers, and service providers."
        />
        <section className="grid gap-6 lg:grid-cols-[0.8fr_1.2fr]">
          <article className="rounded-[30px] border border-slate-200 bg-white p-6">
            <div className="flex items-center justify-between gap-4">
              <div>
                <p className="text-sm text-slate-500">Roles</p>
                <h2 className="text-2xl font-semibold text-slate-950">
                  {buyer.role.replaceAll("_", " ")}
                </h2>
              </div>
              <Pill tone="success">{buyer.verifiedEmail ? "Email verified" : "Verify email"}</Pill>
            </div>
          </article>
          <article className="rounded-[30px] border border-slate-200 bg-white p-6">
            <div className="grid gap-6 md:grid-cols-3">
              <div>
                <p className="text-sm text-slate-500">Saved properties</p>
                <p className="mt-2 text-3xl font-semibold text-slate-950">{savedProperties.length}</p>
              </div>
              <div>
                <p className="text-sm text-slate-500">Saved searches</p>
                <p className="mt-2 text-3xl font-semibold text-slate-950">{savedSearches.length}</p>
              </div>
              <div>
                <p className="text-sm text-slate-500">Preferred locations</p>
                <p className="mt-2 text-sm leading-7 text-slate-600">
                  {buyer.preferredLocations?.join(", ")}
                </p>
              </div>
            </div>
          </article>
        </section>
      </div>
    </AppShell>
  );
}
