import type { TestResult } from "../../diagnostics/tests/suite";

export interface DiagStats {
  events: number; samples: number; evalMs: number; meshMs: number; renderMs: number; sectionMs: number;
  dataBytes: number; materials: number; invalidTransforms: number; maxInverseError: number;
  maxDisplacement: number; maxStrain: number; minDet: number; invalidCells: number; faces: number; worker: boolean; maxResidual: number;
}
const kb = (b: number) => (b > 1e6 ? `${(b / 1e6).toFixed(2)} MB` : `${(b / 1e3).toFixed(1)} kB`);
export function DiagnosticsPanel({ s, tests, running, onRun }: { s: DiagStats; tests: TestResult[]; running: boolean; onRun: () => void }) {
  const rows: [string, string][] = [
    ["geologické události", String(s.events)],
    ["vyhodnocené vzorky (mřížka)", s.samples.toLocaleString("cs")],
    ["výpočet mřížky" + (s.worker ? " (Worker)" : " (hl. vlákno)"), `${s.evalMs.toFixed(1)} ms`],
    ["přímý průřez", `${s.sectionMs.toFixed(1)} ms`],
    ["generování meshe", `${s.meshMs.toFixed(1)} ms · ${s.faces.toLocaleString("cs")} stěn`],
    ["vykreslení (do 2. snímku)", `${s.renderMs.toFixed(1)} ms`],
    ["velikost dat", kb(s.dataBytes)],
    ["různé materiály", String(s.materials)],
    ["neplatné transformace", String(s.invalidTransforms)],
    ["max. chyba inverze", `${s.maxInverseError.toExponential(2)} m`],
    ["max. reziduum (mřížka)", `${s.maxResidual.toExponential(2)} m`],
    ["max. posun / deformace |J−I|", `${s.maxDisplacement.toFixed(2)} m / ${s.maxStrain.toFixed(3)}`],
    ["min. det J", s.minDet.toFixed(4)],
    ["buňky s neplatným výsledkem", String(s.invalidCells)],
  ];
  return (
    <div className="space-y-3">
      <div className="space-y-0.5">{rows.map(([k, v]) => <div key={k} className="lab-kv"><span className="text-muted-foreground">{k}</span><span>{v}</span></div>)}</div>
      <button className="lab-btn w-full" disabled={running} onClick={onRun}>{running ? "Testy běží…" : "Spustit automatické testy"}</button>
      <ul className="space-y-1.5">
        {tests.map((t) => (
          <li key={t.id} className="border border-border p-1.5">
            <div className="flex justify-between font-mono text-[11px]">
              <span className={t.passed ? "text-success" : "text-destructive"}>{t.passed ? "✓" : "✕"} {t.name}</span>
              <span className="text-muted-foreground">{t.ms.toFixed(0)} ms</span>
            </div>
            <div className="font-mono text-[10px] text-muted-foreground">{t.detail}</div>
          </li>
        ))}
      </ul>
    </div>
  );
}
