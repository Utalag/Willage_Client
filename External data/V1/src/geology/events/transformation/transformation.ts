import type { TransformationOperation } from "../types";
/**
 * Transformation events (metamorphism, mineralisation, weathering) are NOT implemented in v0.
 * The evaluator already supports the TransformationOperation interface: it records the
 * historical position of the point at the time of the transformation and applies
 * transformations chronologically after the source material is determined.
 * This helper exists only for tests of that hook.
 */
export function makeTestTransformation(
  id: string,
  fn: (materialId: number, x: number, y: number, z: number) => number,
): TransformationOperation {
  return { kind: "transformation", id, transform: fn, validate: () => ({ valid: true, errors: [], warnings: [] }) };
}
