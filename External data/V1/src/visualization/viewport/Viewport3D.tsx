import { Canvas, useFrame, useThree, type ThreeEvent } from "@react-three/fiber";
import { OrbitControls } from "@react-three/drei";
import { useEffect, useMemo, useRef, type RefObject } from "react";
import * as THREE from "three";
import type { WorldConfig } from "../../core/coordinates/world";
import type { MeshOutput } from "../../voxel/mesh/culledMesher";
import type { SectionResult } from "../../voxel/sampling/sampleGrid";
import type { RenderTheme } from "../theme";
import { SectionPlane } from "./SectionPlane";

function FrameReady({ wrapper, revision, onRendered }: { wrapper: RefObject<HTMLDivElement | null>; revision: unknown; onRendered: (ms: number) => void }) {
  const frames = useRef(0), start = useRef(0);
  const { invalidate } = useThree();
  useEffect(() => {
    frames.current = 0; start.current = performance.now();
    wrapper.current?.removeAttribute("data-scene-ready"); invalidate();
  }, [revision, wrapper, invalidate]);
  useFrame(() => {
    if (frames.current >= 2) return;
    frames.current++;
    if (frames.current === 2) {
      if (wrapper.current) wrapper.current.dataset['sceneReady'] = "true";
      onRendered(performance.now() - start.current);
    } else invalidate();
  });
  return null;
}

function FitCamera({ world, center }: { world: WorldConfig; center: THREE.Vector3 }) {
  const { camera, size, invalidate } = useThree();
  useEffect(() => {
    if (!(camera instanceof THREE.PerspectiveCamera)) return;
    const direction = camera.position.clone().sub(center).normalize();
    camera.lookAt(center);
    const inverse = camera.quaternion.clone().invert();
    const tanV = Math.tan(THREE.MathUtils.degToRad(camera.fov / 2));
    const tanH = tanV * size.width / size.height;
    let distance = 0;
    for (const x of [0, world.sizeX]) for (const y of [0, world.sizeY]) for (const z of [0, world.sizeZ]) {
      const p = new THREE.Vector3(x, y, z).sub(center).applyQuaternion(inverse);
      distance = Math.max(distance, p.z + Math.abs(p.x) / tanH, p.z + Math.abs(p.y) / tanV);
    }
    camera.position.copy(center).addScaledVector(direction, distance * 1.08);
    camera.lookAt(center); camera.updateProjectionMatrix(); invalidate();
  }, [camera, size.width, size.height, world, center, invalidate]);
  return null;
}

/** Pure renderer: the section pixels and mesh are already evaluated; clipping is visual only. */
export function Viewport3D({ mesh, world, res, section, pixels, cut, theme, onPickSection, onPickCell, onRendered }: {
  mesh: MeshOutput | null; world: WorldConfig; res: number;
  section: SectionResult | null; pixels: Uint8Array | null; cut: boolean; theme: RenderTheme;
  onPickSection: (u: number, v: number) => void;
  onPickCell: (i: number, j: number, k: number) => void;
  onRendered: (ms: number) => void;
}) {
  const wrapper = useRef<HTMLDivElement>(null);
  const geom = useMemo(() => {
    if (!mesh) return null;
    const g = new THREE.BufferGeometry();
    g.setAttribute("position", new THREE.BufferAttribute(mesh.positions, 3));
    g.setAttribute("normal", new THREE.BufferAttribute(mesh.normals, 3));
    g.setAttribute("color", new THREE.BufferAttribute(mesh.colors, 3));
    g.setIndex(new THREE.BufferAttribute(mesh.indices, 1)); g.computeBoundingSphere();
    return g;
  }, [mesh]);
  const box = useMemo(() => {
    const base = new THREE.BoxGeometry(world.sizeX, world.sizeY, world.sizeZ);
    const edges = new THREE.EdgesGeometry(base); base.dispose(); return edges;
  }, [world.sizeX, world.sizeY, world.sizeZ]);
  useEffect(() => () => geom?.dispose(), [geom]);
  useEffect(() => () => box.dispose(), [box]);
  const c = useMemo(() => new THREE.Vector3(world.sizeX / 2, world.sizeY / 2, world.sizeZ / 2), [world]);
  const d = Math.max(world.sizeX, world.sizeY, world.sizeZ);
  const clipping = useMemo(() => {
    if (!cut || !section) return [];
    const normal = new THREE.Vector3(section.axis === "x" ? -1 : 0, section.axis === "y" ? -1 : 0, section.axis === "z" ? -1 : 0);
    return [new THREE.Plane(normal, section.pos)];
  }, [cut, section?.axis, section?.pos]);
  const click = (e: ThreeEvent<MouseEvent>) => {
    // Three.js raycasting does not account for shader clipping. Ignore removed intersections.
    if (cut && section && e.point[section.axis] > section.pos + 1e-6) return;
    if (!e.face) return;
    e.stopPropagation();
    const n = e.face.normal, p = e.point;
    const q = (v: number, nn: number) => Math.floor((v - nn * 0.01 * res) / res);
    onPickCell(q(p.x, n.x), q(p.y, n.y), q(p.z, n.z));
  };
  return <div ref={wrapper} className="h-full w-full bg-viewport" data-testid="viewport-3d">
    <Canvas frameloop="demand" camera={{ position: [c.x + d * 1.1, c.y + d * 0.8, c.z + d * 1.3], fov: 40, near: 0.1, far: d * 20 }} dpr={[1, 2]} gl={{ localClippingEnabled: true }}>
      <color attach="background" args={[theme.background]} />
      <ambientLight intensity={1.6} />
      <directionalLight position={[d, d * 2, d * 0.5]} intensity={0.6} />
      {geom && <mesh geometry={geom} onClick={click}>
        <meshLambertMaterial vertexColors clippingPlanes={clipping} />
      </mesh>}
      {section && pixels && <SectionPlane section={section} pixels={pixels} world={world} onPick={onPickSection} />}
      <lineSegments geometry={box} position={c}><lineBasicMaterial color={theme.wire} /></lineSegments>
      <axesHelper args={[d * 0.25]} />
      <OrbitControls target={c} makeDefault />
      <FitCamera world={world} center={c} />
      {(geom || section) && <FrameReady wrapper={wrapper} revision={pixels ?? geom} onRendered={onRendered} />}
    </Canvas>
  </div>;
}
