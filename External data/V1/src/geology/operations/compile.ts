import type { WorldConfig } from "../../core/coordinates/world";
import { SedimentationOperation } from "../events/material/sedimentation";
import { FoldingOperation } from "../events/deformation/folding";
import { FaultOperation } from "../events/deformation/fault";
import type { GeoEvent, GeoOperation, OpContext, ValidationResult } from "../events/types";

/** Operation registry: event definition (plain JSON) → executable operation. Extend here. */
export function compileEvent(ev: GeoEvent, ctx: OpContext): GeoOperation {
  switch (ev.type) {
    case "sedimentation": return new SedimentationOperation(ev, ctx);
    case "fold": return new FoldingOperation(ev, ctx);
    case "fault": return new FaultOperation(ev);
  }
}
export function contextFor(world: WorldConfig): OpContext {
  return {
    yMin: -32,
    yMax: world.sizeY + 32,
    periodX: world.periodicX ? world.sizeX : 0,
    periodZ: world.periodicZ ? world.sizeZ : 0,
  };
}
export interface CompiledTimeline {
  ops: GeoOperation[];
  events: GeoEvent[];
  validations: { id: string; result: ValidationResult }[];
  invalidCount: number;
}
