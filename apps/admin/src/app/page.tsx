import Link from "next/link";
import { allUsers, listings, sellerDashboardMetrics } from "@homeowner/domain";
import { AppShell, SectionHeading, StatCard } from "@homeowner/ui";

export default function AdminHomePage() {
  return (
    <AppShell
      nav={
        <>
          <Link href="/">Overview</Link>
          <Link href="/listings">Listings</Link>
          <Link href="/users">Users</Link>
          <Link href="/rules">Rules</Link>
          <Link href="/reports">Reports</Link>
        </>
      }
    >
      <div className="space-y-10">
        <SectionHeading
          eyebrow="Operations"
          title="Compliance and trust console"
          description="Support, moderation, and compliance teams can review disclosures, flagged conversations, service providers, and status transitions without blocking the owner-to-buyer core workflow."
        />
        <div className="grid gap-4 md:grid-cols-4">
          <StatCard label="Listings" value={listings.length} />
          <StatCard label="Users" value={allUsers.length} />
          <StatCard label="Upcoming inspections" value={sellerDashboardMetrics.upcomingInspections} />
          <StatCard label="Compliance tasks" value={sellerDashboardMetrics.complianceTasks} />
        </div>
      </div>
    </AppShell>
  );
}
