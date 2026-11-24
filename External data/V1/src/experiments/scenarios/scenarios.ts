import { CLAYSTONE, CONGLOMERATE, LIMESTONE, SANDSTONE, SHALE } from "../../core/materials/materials";
import type { FaultEvent, FoldEvent, GeoEvent, SedimentationEvent } from "../../geology/events/types";
import { createEvent, retime } from "../../geology/timeline/timeline";

const sed = (id: string): SedimentationEvent => {
  const e = createEvent("sedimentation", id) as SedimentationEvent;
  e.name = "Sedimentace – základ";
  e.params = {
    yStart: 6, yEnd: 40, thicknessVariation: 0.35, thicknessFrequency: 0.03, roughness: 0.8, roughnessFrequency: 0.12, mode: "erode",
    local: [{ x: 48, z: 16, radius: 14, factor: 0.4 }],
    layers: [
      { materialId: CONGLOMERATE, thickness: 6 }, { materialId: SANDSTONE, thickness: 8 }, { materialId: CLAYSTONE, thickness: 5 },
      { materialId: LIMESTONE, thickness: 9 }, { materialId: SHALE, thickness: 6 },
    ],
  };
  return e;
};
const fold = (id: string, p: Partial<FoldEvent["params"]>): FoldEvent => {
  const e = createEvent("fold", id) as FoldEvent;
  e.params = { ...e.params, ...p };
  return e;
};
const fault = (id: string, p: Partial<FaultEvent["params"]>): FaultEvent => {
  const e = createEvent("fault", id) as FaultEvent;
  e.params = { ...e.params, ...p };
  return e;
};

export interface Scenario { id: string; name: string; purpose: string; build: () => GeoEvent[] }
export const SCENARIOS: Scenario[] = [
  { id: "A", name: "A – Sedimentární základ", purpose: "Ověření generování sedimentace.", build: () => retime([sed("sedimentation-1")]) },
  { id: "B", name: "B – Mírné vrásnění", purpose: "Zachování spojitosti vrstev.", build: () => retime([sed("sedimentation-1"), fold("fold-1", { amplitude: 2.5, wavelength: 60 })]) },
  {
    id: "C", name: "C – Výrazné vrásnění", purpose: "Skládání transformací.",
    build: () => retime([sed("sedimentation-1"), fold("fold-1", { amplitude: 5, wavelength: 34, azimuthDeg: 15 }), fold("fold-2", { amplitude: 2.5, wavelength: 18, azimuthDeg: 105, irregularity: 0.3, phaseDeg: 40 })]),
  },
  {
    id: "D", name: "D – Tektonický zlom", purpose: "Nespojitost a historické pořadí.",
    build: () => retime([sed("sedimentation-1"), fold("fold-1", { amplitude: 3, wavelength: 44 }), fault("fault-1", { strikeDeg: 90, dipDeg: 60, displacement: 9, damageWidth: 1.2 })]),
  },
  {
    id: "E", name: "E – Komplexní geologie", purpose: "Mladší sedimentace překrývá deformované struktury.",
    build: () => {
      const s2 = createEvent("sedimentation", "sedimentation-2") as SedimentationEvent;
      s2.name = "Sedimentace – pokryv";
      s2.params.yStart = 36; s2.params.yEnd = 50;
      return retime([
        sed("sedimentation-1"),
        fold("fold-1", { amplitude: 5, wavelength: 36, azimuthDeg: 10 }),
        fold("fold-2", { amplitude: 2, wavelength: 20, azimuthDeg: 100 }),
        fault("fault-1", { strikeDeg: 75, dipDeg: 55, displacement: 8, damageWidth: 1 }),
        s2,
      ]);
    },
  },
];
