import type { WorldConfig } from "../../core/coordinates/world";
import { hashString } from "../../core/deterministic/hash";
import { CLAYSTONE, CONGLOMERATE, LIMESTONE, SANDSTONE, SHALE } from "../../core/materials/materials";
import type { FaultEvent, FoldEvent, GeoEvent, GeoEventType, SedimentationEvent } from "../events/types";
import { compileEvent, contextFor, type CompiledTimeline } from "../operations/compile";

/** Index 0 = oldest. Array order IS the chronology. */
export interface TimelineQuery {
  /** Evaluate history only up to (and including) this index. */
  upToIndex?: number | null;
  /** Show only the isolated effect of one event. */
  isolateId?: string | null;
}

/** Flat reference stratigraphy used to visualise the isolated effect of a deformation. */
export const REFERENCE_STRATA: SedimentationEvent = {
  id: "__reference", name: "Referenční vrstvy", time: 0, seed: 1, algorithmVersion: 1, enabled: true, dependsOn: [], type: "sedimentation",
  params: {
    yStart: 6, yEnd: 46, thicknessVariation: 0, thicknessFrequency: 0.02, roughness: 0, roughnessFrequency: 0.1, mode: "erode", local: [],
    layers: [SANDSTONE, CLAYSTONE, LIMESTONE, SHALE, CONGLOMERATE, SANDSTONE, CLAYSTONE, LIMESTONE].map((m) => ({ materialId: m, thickness: 5 })),
  },
};

export function selectEvents(events: GeoEvent[], q: TimelineQuery = {}): GeoEvent[] {
  if (q.isolateId) {
    const ev = events.find((e) => e.id === q.isolateId);
    if (!ev) return [];
    return ev.type === "sedimentation" ? [ev] : [REFERENCE_STRATA, ev];
  }
  const upTo = q.upToIndex ?? events.length - 1;
  return events.slice(0, upTo + 1).filter((e) => e.enabled);
}

export function compileTimeline(events: GeoEvent[], world: WorldConfig, q: TimelineQuery = {}): CompiledTimeline {
  const ctx = contextFor(world);
  const sel = selectEvents(events, q);
  const ops = sel.map((e) => compileEvent(e, ctx));
  const validations = ops.map((o, i) => {
    const r = o.validate();
    const ev = sel[i]!;
    for (const d of ev.dependsOn) {
      const di = sel.findIndex((e) => e.id === d);
      if (di < 0 || di >= i) r.errors.push(`Závislost ${d} není starší událost.`);
    }
    r.valid = r.errors.length === 0;
    return { id: o.id, result: r };
  });
  return { ops, events: sel, validations, invalidCount: validations.filter((v) => !v.result.valid).length };
}

/** Re-derive informative ages from order: oldest = n·10 Ma. */
export const retime = (events: GeoEvent[]): GeoEvent[] =>
  events.map((e, i) => ({ ...e, time: (events.length - i) * 10 }));

export function nextId(events: GeoEvent[], type: GeoEventType): string {
  let n = 1;
  while (events.some((e) => e.id === `${type}-${n}`)) n++;
  return `${type}-${n}`;
}

export function createEvent(type: GeoEventType, id: string): GeoEvent {
  const base = { id, time: 0, seed: hashString(id), algorithmVersion: 1, enabled: true, dependsOn: [] as string[] };
  if (type === "sedimentation") {
    const e: SedimentationEvent = {
      ...base, type, name: "Sedimentace",
      params: {
        yStart: 40, yEnd: 52, thicknessVariation: 0.3, thicknessFrequency: 0.03, roughness: 0.6, roughnessFrequency: 0.12, mode: "erode", local: [],
        layers: [{ materialId: SANDSTONE, thickness: 4 }, { materialId: CLAYSTONE, thickness: 3 }, { materialId: LIMESTONE, thickness: 5 }],
      },
    };
    return e;
  }
  if (type === "fold") {
    const e: FoldEvent = {
      ...base, type, name: "Vrásnění",
      params: { amplitude: 3, wavelength: 40, azimuthDeg: 0, phaseDeg: 0, intensity: 1, irregularity: 0, irregularityFrequency: 0.03, depthGradient: 0, yRef: 32, extent: { cx: 32, cz: 32, radius: 0, falloff: 16 } },
    };
    return e;
  }
  const e: FaultEvent = {
    ...base, type, name: "Zlom",
    params: { x: 32, y: 24, z: 32, strikeDeg: 90, dipDeg: 60, displacement: 6, faultType: "normal", rakeDeg: 45, damageWidth: 1 },
  };
  return e;
}
