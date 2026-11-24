import type { WorldConfig } from "../core/coordinates/world";
import type { GeoEvent } from "../geology/events/types";
import type { TimelineQuery } from "../geology/timeline/timeline";
import type { SectionAxis } from "../voxel/sampling/sampleGrid";

export type WorkerRequest =
  | { type: "grid"; reqId: number; events: GeoEvent[]; world: WorldConfig; res: number; query: TimelineQuery }
  | { type: "section"; reqId: number; events: GeoEvent[]; world: WorldConfig; axis: SectionAxis; pos: number; pxPerM: number; query: TimelineQuery };
