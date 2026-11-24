import type { WorldConfig } from "../../core/coordinates/world";
import type { Vec3 } from "../../core/math/vec3";

export type SectionAxis = "x" | "y" | "z";

export function sectionSize(world: WorldConfig, axis: SectionAxis) {
  return { u: axis === "x" ? world.sizeZ : world.sizeX, v: axis === "y" ? world.sizeZ : world.sizeY };
}

/** Top-left raster convention: X/Z sections have Y upwards; Y sections have Z downwards. */
export function sectionPixelPoint(world: WorldConfig, axis: SectionAxis, pos: number, u: number, v: number, pxPerM: number, out: Vec3 = { x: 0, y: 0, z: 0 }): Vec3 {
  const uc = (u + 0.5) / pxPerM;
  const vc = sectionSize(world, axis).v - (v + 0.5) / pxPerM;
  out.x = axis === "x" ? pos : uc;
  out.y = axis === "y" ? pos : vc;
  out.z = axis === "z" ? pos : axis === "x" ? uc : world.sizeZ - vc;
  return out;
}

/** Both 2D and 3D clicks select the same sampled pixel, including the last row/column. */
export function sectionPickPoint(world: WorldConfig, section: { axis: SectionAxis; pos: number; w: number; h: number; pxPerM: number }, u: number, v: number): Vec3 {
  const col = Math.max(0, Math.min(section.w - 1, Math.floor(u * section.w)));
  const row = Math.max(0, Math.min(section.h - 1, Math.floor(v * section.h)));
  return sectionPixelPoint(world, section.axis, section.pos, col, row, section.pxPerM);
}

/** Presentation geometry only; no material classification or deformation here. */
export function sectionCorners(world: WorldConfig, axis: SectionAxis, pos: number): number[] {
  const { sizeX: x, sizeY: y, sizeZ: z } = world;
  if (axis === "x") return [pos, y, 0, pos, y, z, pos, 0, z, pos, 0, 0];
  if (axis === "z") return [0, y, pos, x, y, pos, x, 0, pos, 0, 0, pos];
  return [0, pos, 0, x, pos, 0, x, pos, z, 0, pos, z];
}