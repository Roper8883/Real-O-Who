import Link from "next/link";
import { conversations, listings } from "@homeowner/domain";
import { AppShell, Pill, SectionHeading } from "@homeowner/ui";

export default function MessagesPage() {
  return (
    <AppShell
      nav={
        <>
          <Link href="/">Home</Link>
          <Link href="/buy">Buy</Link>
          <Link href="/messages">Messages</Link>
          <Link href="/inspections">Inspections</Link>
        </>
      }
    >
      <div className="space-y-8">
        <SectionHeading
          eyebrow="Direct messaging"
          title="Owner-to-buyer conversations with audit history"
          description="Messages stay tied to the property, support attachments, preserve system notices, and keep contact details masked until both parties choose to reveal them."
        />
        <div className="grid gap-6 lg:grid-cols-[0.95fr_1.05fr]">
          <aside className="space-y-4 rounded-[30px] border border-slate-200 bg-white p-6">
            {conversations.map((conversation) => {
              const listing = listings.find((item) => item.id === conversation.listingId);
              return (
                <article
                  className="rounded-2xl border border-slate-200 p-4"
                  key={conversation.id}
                >
                  <div className="flex items-center justify-between gap-4">
                    <div>
                      <p className="font-semibold text-slate-900">{listing?.title}</p>
                      <p className="text-sm text-slate-600">
                        {conversation.lastMessagePreview}
                      </p>
                    </div>
                    <Pill tone={conversation.unreadCount ? "accent" : "neutral"}>
                      {conversation.unreadCount} unread
                    </Pill>
                  </div>
                </article>
              );
            })}
          </aside>
          <section className="rounded-[30px] border border-slate-200 bg-white p-6">
            <h2 className="text-lg font-semibold text-slate-950">Current thread</h2>
            <div className="mt-5 space-y-4">
              {conversations[0]?.messages.map((message) => (
                <div
                  className={`rounded-2xl p-4 text-sm leading-7 ${
                    message.system
                      ? "bg-amber-50 text-amber-900"
                      : "bg-slate-50 text-slate-700"
                  }`}
                  key={message.id}
                >
                  {message.body}
                </div>
              ))}
            </div>
          </section>
        </div>
      </div>
    </AppShell>
  );
}
