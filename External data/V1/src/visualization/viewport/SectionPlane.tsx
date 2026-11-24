import { useEffect, useMemo } from "react";
import type { ThreeEvent } from "@react-three/fiber";
import * as THREE from "three";
import type { WorldConfig } from "../../core/coordinates/world";
import type { SectionResult } from "../../voxel/sampling/sampleGrid";
import { sectionCorners } from "../../voxel/sampling/sectionCoordinates";

/** Raster produced by the evaluator, placed on its exact world-space plane. */
export function SectionPlane({ section, pixels, world, onPick }: {
  section: SectionResult; pixels: Uint8Array; world: WorldConfig; onPick: (u: number, v: number) => void;
}) {
  const geometry = useMemo(() => {
    const g = new THREE.BufferGeometry();
    g.setAttribute("position", new THREE.Float32BufferAttribute(sectionCorners(world, section.axis, section.pos), 3));
    // DataTexture row zero is at v=0; both the raster and picking use top-left coordinates.
    g.setAttribute("uv", new THREE.Float32BufferAttribute([0, 0, 1, 0, 1, 1, 0, 1], 2));
    g.setIndex([0, 1, 2, 0, 2, 3]);
    g.computeVertexNormals();
    return g;
  }, [world, section.axis, section.pos]);
  const texture = useMemo(() => {
    const t = new THREE.DataTexture(pixels, section.w, section.h, THREE.RGBAFormat);
    t.magFilter = THREE.NearestFilter; t.minFilter = THREE.NearestFilter;
    t.colorSpace = THREE.SRGBColorSpace; t.needsUpdate = true;
    return t;
  }, [pixels, section.w, section.h]);
  useEffect(() => () => geometry.dispose(), [geometry]);
  useEffect(() => () => texture.dispose(), [texture]);
  const click = (e: ThreeEvent<MouseEvent>) => {
    if (!e.uv) return;
    const u = Math.max(0, Math.min(section.w - 1, Math.floor(e.uv.x * section.w)));
    const v = Math.max(0, Math.min(section.h - 1, Math.floor(e.uv.y * section.h)));
    if ((pixels[(u + v * section.w) * 4 + 3] ?? 0) === 0) return;
    e.stopPropagation(); onPick(e.uv.x, e.uv.y);
  };
  return <mesh geometry={geometry} onClick={click}>
    <meshBasicMaterial map={texture} side={THREE.DoubleSide} transparent alphaTest={0.5} toneMapped={false} />
  </mesh>;
}