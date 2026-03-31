import Link from "next/link";
import { allUsers } from "@homeowner/domain";
import { AppShell, Pill, SectionHeading } from "@homeowner/ui";

export default function AdminUsersPage() {
  return (
    <AppShell
      nav={
        <>
          <Link href="/">Overview</Link>
          <Link href="/listings">Listings</Link>
          <Link href="/users">Users</Link>
          <Link href="/reports">Reports</Link>
        </>
      }
    >
      <div className="space-y-8">
        <SectionHeading
          eyebrow="Users"
          title="Role-aware identity and account operations"
          description="Admin teams can review buyer, seller, inspector, support, and compliance users with identity status, audit access, and account controls."
        />
        <div className="grid gap-4 md:grid-cols-2">
          {allUsers.map((user) => (
            <article className="rounded-[28px] border border-slate-200 bg-white p-5" key={user.id}>
              <div className="flex items-center justify-between gap-4">
                <div>
                  <p className="font-semibold text-slate-950">{user.displayName}</p>
                  <p className="text-sm text-slate-600">{user.email}</p>
                </div>
                <Pill tone={user.verifiedEmail ? "success" : "warning"}>
                  {user.role.replaceAll("_", " ")}
                </Pill>
              </div>
            </article>
          ))}
        </div>
      </div>
    </AppShell>
  );
}
