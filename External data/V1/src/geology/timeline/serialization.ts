import type { WorldConfig } from "../../core/coordinates/world";
import { MATERIALS, type Material } from "../../core/materials/materials";
import type { GeoEvent } from "../events/types";

/** Versioned JSON contract (future C# server). Bump on breaking schema change. */
export const SCHEMA_VERSION = 1;
export interface TimelineDocument {
  schemaVersion: number;
  engine: "willage-geology-ts";
  axes: "Y-up, X/Z horizontal, metres";
  world: WorldConfig;
  materials: Material[];
  events: GeoEvent[];
}
export function exportTimeline(events: GeoEvent[], world: WorldConfig): TimelineDocument {
  return { schemaVersion: SCHEMA_VERSION, engine: "willage-geology-ts", axes: "Y-up, X/Z horizontal, metres", world, materials: [...MATERIALS], events };
}
export function importTimeline(json: unknown): { world: WorldConfig; events: GeoEvent[] } {
  const d = json as Partial<TimelineDocument>;
  if (!d || typeof d !== "object") throw new Error("Neplatný JSON.");
  if (d.schemaVersion !== SCHEMA_VERSION) throw new Error(`Nepodporovaná schemaVersion ${String(d.schemaVersion)} (očekáváno ${SCHEMA_VERSION}).`);
  if (!Array.isArray(d.events) || !d.world) throw new Error("Chybí events nebo world.");
  for (const e of d.events) {
    if (typeof e.id !== "string" || typeof e.seed !== "number" || typeof e.algorithmVersion !== "number")
      throw new Error("Každá událost musí mít id, seed a algorithmVersion.");
    if (e.algorithmVersion !== 1) throw new Error(`Událost ${e.id}: algorithmVersion ${e.algorithmVersion} není podporována.`);
  }
  return { world: d.world, events: d.events };
}
