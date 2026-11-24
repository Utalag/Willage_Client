import { ArrowDown, ArrowUp, Eye, EyeOff, History, Trash2, Crosshair } from "lucide-react";
import { EVENT_CATEGORY, type GeoEvent, type GeoEventType } from "../../geology/events/types";

const TYPE_LABEL: Record<GeoEventType, string> = { sedimentation: "Sedimentace", fold: "Vrásnění", fault: "Zlom" };

export function TimelinePanel(props: {
  events: GeoEvent[];
  selectedId: string | null;
  isolateId: string | null;
  upToIndex: number | null;
  invalidIds: Set<string>;
  onSelect: (id: string) => void;
  onToggle: (id: string) => void;
  onMove: (id: string, d: -1 | 1) => void;
  onDelete: (id: string) => void;
  onIsolate: (id: string | null) => void;
  onUpTo: (i: number | null) => void;
  onAdd: (t: GeoEventType) => void;
}) {
  const { events } = props;
  return (
    <div className="space-y-2">
      <div className="flex flex-wrap gap-1">
        {(["sedimentation", "fold", "fault"] as const).map((t) => (
          <button key={t} className="lab-btn" onClick={() => props.onAdd(t)}>+ {TYPE_LABEL[t]}</button>
        ))}
      </div>
      <div className="lab-heading">nejmladší ↑</div>
      <ol className="space-y-1">
        {[...events].map((e, i) => ({ e, i })).reverse().map(({ e, i }) => {
          const sel = e.id === props.selectedId;
          const beyond = props.upToIndex !== null && i > props.upToIndex;
          return (
            <li key={e.id}
              className={`cursor-pointer border px-2 py-1.5 transition-colors ${sel ? "border-primary bg-secondary" : "border-border bg-background hover:border-muted-foreground"} ${beyond || !e.enabled ? "opacity-45" : ""}`}
              onClick={() => props.onSelect(e.id)}>
              <div className="flex items-center justify-between gap-1">
                <div className="min-w-0">
                  <div className="truncate text-xs font-medium">{i + 1}. {e.name}</div>
                  <div className="font-mono text-[10px] text-muted-foreground">
                    {TYPE_LABEL[e.type]} · {EVENT_CATEGORY[e.type]} · {e.time} Ma · seed {e.seed}
                    {props.invalidIds.has(e.id) && <span className="text-destructive"> · neplatné</span>}
                  </div>
                </div>
                <div className="flex shrink-0 gap-0.5" onClick={(ev) => ev.stopPropagation()}>
                  <button className="lab-btn px-1" title="Zapnout/vypnout" onClick={() => props.onToggle(e.id)}>{e.enabled ? <Eye size={12} /> : <EyeOff size={12} />}</button>
                  <button className={`lab-btn px-1 ${props.isolateId === e.id ? "lab-btn-active" : ""}`} title="Jen samostatný účinek" onClick={() => props.onIsolate(props.isolateId === e.id ? null : e.id)}><Crosshair size={12} /></button>
                  <button className={`lab-btn px-1 ${props.upToIndex === i ? "lab-btn-active" : ""}`} title="Stav do tohoto okamžiku" onClick={() => props.onUpTo(props.upToIndex === i ? null : i)}><History size={12} /></button>
                  <button className="lab-btn px-1" title="Mladší" disabled={i === events.length - 1} onClick={() => props.onMove(e.id, 1)}><ArrowUp size={12} /></button>
                  <button className="lab-btn px-1" title="Starší" disabled={i === 0} onClick={() => props.onMove(e.id, -1)}><ArrowDown size={12} /></button>
                  <button className="lab-btn px-1" title="Odstranit" onClick={() => props.onDelete(e.id)}><Trash2 size={12} /></button>
                </div>
              </div>
            </li>
          );
        })}
      </ol>
      <div className="lab-heading">nejstarší ↓ · podloží: krystalinikum</div>
    </div>
  );
}
