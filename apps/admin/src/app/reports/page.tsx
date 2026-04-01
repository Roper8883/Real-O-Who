import Link from "next/link";
import { conversations } from "@homeowner/domain";
import { AppShell, Pill, SectionHeading } from "@homeowner/ui";

const mobileNavItems = [
  { href: "/", label: "Home" },
  { href: "/listings", label: "Listings" },
  { href: "/users", label: "Users" },
  { href: "/reports", label: "Reports" },
  { href: "/rules", label: "Rules" },
];

export default function AdminReportsPage() {
  return (
    <AppShell
      mobileNavItems={mobileNavItems}
      nav={
        <>
          <Link href="/">Overview</Link>
          <Link href="/listings">Listings</Link>
          <Link href="/rules">Rules</Link>
          <Link href="/reports">Reports</Link>
        </>
      }
    >
      <div className="space-y-8">
        <SectionHeading
          eyebrow="Moderation"
          title="Reported content, suspicious conversations, and support intervention"
          description="Moderation tooling keeps human review in the loop for abuse, harassment, scam language, and off-platform pressure."
        />
        <div className="grid gap-4">
          {conversations.map((conversation) => (
            <article className="rounded-[28px] border border-slate-200 bg-white p-5" key={conversation.id}>
              <div className="flex items-center justify-between gap-4">
                <div>
                  <p className="font-semibold text-slate-950">{conversation.lastMessagePreview}</p>
                  <p className="text-sm text-slate-600">
                    {conversation.messages.length} messages in audit history
                  </p>
                </div>
                <Pill tone={conversation.flagged ? "warning" : "success"}>
                  {conversation.flagged ? "Flagged" : "Clear"}
                </Pill>
              </div>
            </article>
          ))}
        </div>
      </div>
    </AppShell>
  );
}
