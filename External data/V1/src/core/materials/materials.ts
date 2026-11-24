/** Material database – pure data, no algorithm depends on anything but the IDs. */
export interface Material {
  id: number;
  key: string;
  name: string;
  color: string;
  /** kg/m³ */ density: number;
  /** Mohs-like 1–10 */ hardness: number;
  /** fraction 0–1 */ porosity: number;
  /** millidarcy */ permeability: number;
  /** relative 0–1 */ erosionResistance: number;
}
export const AIR = 0;
export const SANDSTONE = 1;
export const CLAYSTONE = 2;
export const LIMESTONE = 3;
export const SHALE = 4;
export const CONGLOMERATE = 5;
export const BASEMENT = 6;
export const BRECCIA = 7;

export const MATERIALS: readonly Material[] = [
  { id: AIR, key: "air", name: "Vzduch / prázdno", color: "#000000", density: 1.2, hardness: 0, porosity: 1, permeability: 0, erosionResistance: 0 },
  { id: SANDSTONE, key: "sandstone", name: "Pískovec", color: "#e8b04a", density: 2300, hardness: 6, porosity: 0.2, permeability: 500, erosionResistance: 0.55 },
  { id: CLAYSTONE, key: "claystone", name: "Jílovec", color: "#b5523b", density: 2200, hardness: 2.5, porosity: 0.35, permeability: 0.01, erosionResistance: 0.25 },
  { id: LIMESTONE, key: "limestone", name: "Vápenec", color: "#d9dccb", density: 2600, hardness: 3, porosity: 0.1, permeability: 10, erosionResistance: 0.7 },
  { id: SHALE, key: "shale", name: "Břidlice", color: "#3f5872", density: 2500, hardness: 3.5, porosity: 0.08, permeability: 0.001, erosionResistance: 0.45 },
  { id: CONGLOMERATE, key: "conglomerate", name: "Slepenec", color: "#7f9a4a", density: 2450, hardness: 5.5, porosity: 0.15, permeability: 100, erosionResistance: 0.8 },
  { id: BASEMENT, key: "basement", name: "Krystalinikum (podloží)", color: "#5c4d6b", density: 2750, hardness: 6.5, porosity: 0.01, permeability: 0.0001, erosionResistance: 0.95 },
  { id: BRECCIA, key: "fault_breccia", name: "Drcená zóna (brekcie)", color: "#ff3d6e", density: 2350, hardness: 3, porosity: 0.25, permeability: 1000, erosionResistance: 0.2 },
];
export const SEDIMENT_MATERIAL_IDS = [SANDSTONE, CLAYSTONE, LIMESTONE, SHALE, CONGLOMERATE];
export const materialById = (id: number) => MATERIALS[id] ?? MATERIALS[0]!;
