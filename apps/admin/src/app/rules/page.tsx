import Link from "next/link";
import { getRuleSet } from "@homeowner/domain";
import { AppShell, SectionHeading } from "@homeowner/ui";

const states = ["NSW", "VIC", "QLD", "SA", "ACT", "NT", "WA", "TAS"] as const;

export default function AdminRulesPage() {
  return (
    <AppShell
      nav={
        <>
          <Link href="/">Overview</Link>
          <Link href="/rules">Rules</Link>
          <Link href="/reports">Reports</Link>
        </>
      }
    >
      <div className="space-y-8">
        <SectionHeading
          eyebrow="Jurisdiction rules"
          title="State-aware publishing and offer guardrails"
          description="The rules engine is data-driven so admin teams can maintain legal workflow switches without hard-coding the whole product."
        />
        <div className="grid gap-4">
          {states.map((state) => {
            const rules = getRuleSet(state);
            return (
              <article className="rounded-[28px] border border-slate-200 bg-white p-5" key={state}>
                <h2 className="text-xl font-semibold text-slate-950">{state}</h2>
                <p className="mt-2 text-sm leading-7 text-slate-600">{rules.disclosureSummary}</p>
                <p className="mt-3 text-sm text-slate-500">{rules.coolingOff.note}</p>
              </article>
            );
          })}
        </div>
      </div>
    </AppShell>
  );
}
