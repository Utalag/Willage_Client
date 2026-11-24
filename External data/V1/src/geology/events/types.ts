import type { Vec3 } from "../../core/math/vec3";

/** Spatial extent of an event in the horizontal XZ plane. radius <= 0 means unlimited. */
export interface Extent { cx: number; cz: number; radius: number; falloff: number }

interface BaseEvent {
  /** Stable identifier – never reused, survives reordering. */
  id: string;
  name: string;
  /** Informative geological age in Ma (derived from order, oldest = largest). */
  time: number;
  /** Per-event seed. All noise of the event derives from it. */
  seed: number;
  algorithmVersion: number;
  enabled: boolean;
  /** IDs of events this one requires (informative; validated to be older). */
  dependsOn: string[];
}

export interface SedimentLayer { materialId: number; thickness: number }
export interface LocalThickness { x: number; z: number; radius: number; factor: number }
export interface SedimentationParams {
  /** height (Y) of the erosion/deposition base */ yStart: number;
  yEnd: number;
  layers: SedimentLayer[];
  /** Relative low-frequency thickness variation, 0–0.9. */
  thicknessVariation: number;
  /** cycles/m */
  thicknessFrequency: number;
  /** Interface roughness amplitude in metres. */
  roughness: number;
  /** cycles/m */
  roughnessFrequency: number;
  /** erode = older material above yStart is removed (unconformity); onlap = fills only empty space. */
  mode: "erode" | "onlap";
  local: LocalThickness[];
}
export interface FoldParams {
  amplitude: number;
  wavelength: number;
  azimuthDeg: number;
  phaseDeg: number;
  intensity: number;
  irregularity: number;
  irregularityFrequency: number;
  /** 1/m – vertical amplitude gradient γ: amplitude scales with exp(γ (y - yRef)). γ = 0 → analytic inverse. */
  depthGradient: number;
  yRef: number;
  extent: Extent;
}
export type FaultType = "normal" | "reverse" | "strike-slip" | "oblique";
export interface FaultParams {
  x: number; y: number; z: number;
  strikeDeg: number;
  dipDeg: number;
  displacement: number;
  faultType: FaultType;
  rakeDeg: number;
  damageWidth: number;
}

export interface SedimentationEvent extends BaseEvent { type: "sedimentation"; params: SedimentationParams }
export interface FoldEvent extends BaseEvent { type: "fold"; params: FoldParams }
export interface FaultEvent extends BaseEvent { type: "fault"; params: FaultParams }
export type GeoEvent = SedimentationEvent | FoldEvent | FaultEvent;
export type GeoEventType = GeoEvent["type"];
export const EVENT_CATEGORY: Record<GeoEventType, "material" | "deformation" | "transformation"> = {
  sedimentation: "material",
  fold: "deformation",
  fault: "deformation",
};

export interface ValidationResult { valid: boolean; errors: string[]; warnings: string[] }
export interface InverseResult { iterations: number; residual: number; converged: boolean }

/** Context every operation receives at compile time. */
export interface OpContext { yMin: number; yMax: number; periodX: number; periodZ: number }

/** DeformationEvent: changes geometry. Must define forward AND inverse. */
export interface DeformationOperation {
  readonly kind: "deformation";
  readonly id: string;
  /** p_before → p_after */
  forward(p: Vec3, out: Vec3): void;
  /** p_after → p_before (exact or numerical). */
  inverse(p: Vec3, out: Vec3): InverseResult;
  isInvertible(): boolean;
  validate(): ValidationResult;
  /** Writes row-major 3x3 ∂forward/∂p into out, returns det. */
  evaluateJacobian(p: Vec3, out: Float64Array): number;
  /** Optional flag zone in post-event coordinates (fault damage zone). */
  damageAt?(x: number, y: number, z: number): boolean;
}

export const LAYER_BELOW = -1;
export const LAYER_ABOVE = -2;
/** MaterialEvent: creates material at its deposition-time coordinates. */
export interface MaterialOperation {
  readonly kind: "material";
  readonly id: string;
  readonly mode: "erode" | "onlap";
  /** Layer index ≥ 0, LAYER_BELOW or LAYER_ABOVE. */
  classify(x: number, y: number, z: number): number;
  materialOf(layer: number): number;
  validate(): ValidationResult;
}

/**
 * TransformationEvent (metamorphism, mineralisation, weathering…). Interface only in v0.
 * Receives the position the point had AT THE TIME of the transformation.
 */
export interface TransformationOperation {
  readonly kind: "transformation";
  readonly id: string;
  /** Returns new material id (or the same one). */
  transform(materialId: number, x: number, y: number, z: number): number;
  validate(): ValidationResult;
}

export type GeoOperation = DeformationOperation | MaterialOperation | TransformationOperation;
export const ok = (): ValidationResult => ({ valid: true, errors: [], warnings: [] });
