interface StatCardProps {
  label: string;
  value: string | number;
  detail?: string;
}

export function StatCard({ label, value, detail }: StatCardProps) {
  return (
    <article className="rounded-[28px] border border-slate-200 bg-white p-6 shadow-sm shadow-slate-200/40">
      <p className="text-sm font-medium text-slate-500">{label}</p>
      <p className="mt-3 text-3xl font-semibold tracking-tight text-slate-950">
        {value}
      </p>
      {detail ? <p className="mt-3 text-sm text-slate-600">{detail}</p> : null}
    </article>
  );
}
