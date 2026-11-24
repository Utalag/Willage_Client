import type { ReactNode } from "react";

export function Num({ label, value, onChange, min, max, step = 0.1, unit }: {
  label: string; value: number; onChange: (v: number) => void; min: number; max: number; step?: number; unit?: string;
}) {
  return (
    <label className="block space-y-0.5">
      <div className="flex items-center justify-between font-mono text-[10px] text-muted-foreground">
        <span>{label}</span>
        <span className="flex items-center gap-1">
          <input
            type="number" aria-label={label} className="lab-input w-16 text-right" value={Number(value.toFixed(4))} step={step}
            onChange={(e) => { const v = parseFloat(e.target.value); if (Number.isFinite(v)) onChange(v); }}
          />
          {unit && <span className="w-6">{unit}</span>}
        </span>
      </div>
      <input type="range" aria-label={`${label} – posuvník`} className="lab-range" min={min} max={max} step={step} value={value} onChange={(e) => onChange(parseFloat(e.target.value))} />
    </label>
  );
}
export function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="space-y-2 border-t border-border pt-2 first:border-t-0 first:pt-0">
      <div className="lab-heading">{title}</div>
      {children}
    </div>
  );
}
export function Select<T extends string | number>({ label, value, options, onChange }: {
  label: string; value: T; options: { value: T; label: string }[]; onChange: (v: T) => void;
}) {
  return (
    <label className="flex items-center justify-between gap-2 font-mono text-[10px] text-muted-foreground">
      <span>{label}</span>
      <select
        className="lab-input w-auto"
        aria-label={label}
        value={String(value)}
        onChange={(e) => { const o = options.find((x) => String(x.value) === e.target.value); if (o) onChange(o.value); }}
      >
        {options.map((o) => <option key={String(o.value)} value={String(o.value)}>{o.label}</option>)}
      </select>
    </label>
  );
}
