import { materialById } from "../../core/materials/materials";
import type { GeoEvent } from "../../geology/events/types";

export interface InspectResult {
  p: [number, number, number];
  materialId: number;
  sourceEventId: string | null;
  bodyId: null;
  layerIndex: number;
  flags: number;
  stages: { label: string; pos: [number, number, number] | null }[];
}
export function Inspector({ r, events }: { r: InspectResult | null; events: GeoEvent[] }) {
  if (!r) return <p className="font-mono text-[11px] text-muted-foreground">Klikněte na voxel nebo do průřezu.</p>;
  const m = materialById(r.materialId);
  const src = events.find((e) => e.id === r.sourceEventId);
  const f = (v: number) => v.toFixed(3);
  return (
    <div className="space-y-2 font-mono text-[11px]">
      <div className="lab-kv"><span className="text-muted-foreground">bod (x, y, z)</span><span>{r.p.map(f).join(", ")}</span></div>
      <div className="lab-kv"><span className="text-muted-foreground">materiál</span><span className="flex items-center gap-1"><i className="inline-block h-2.5 w-2.5" style={{ background: m.color }} />{m.id} · {m.name}</span></div>
      <div className="lab-kv"><span className="text-muted-foreground">událost</span><span className="min-w-0 break-words text-right">{r.sourceEventId ?? "— (podloží/vzduch)"}{src ? ` · ${src.name}` : ""}</span></div>
      <div className="lab-kv"><span className="text-muted-foreground">ID tělesa</span><span>{String(r.bodyId)}</span></div>
      <div className="lab-kv"><span className="text-muted-foreground">vrstva · příznaky</span><span>{r.layerIndex} · {r.flags}</span></div>
      <div className="lab-heading pt-1">historické souřadnice</div>
      <table className="w-full table-fixed">
        <tbody>
          {r.stages.map((s, i) => (
            <tr key={i} className="border-t border-border">
              <td className="w-6 py-0.5 pr-1 text-muted-foreground">p{i}</td>
              <td className="py-0.5 pr-1 break-words">{s.label}</td>
              <td className="py-0.5 text-right break-words">{s.pos ? s.pos.map(f).join(", ") : "nenavštíveno"}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
