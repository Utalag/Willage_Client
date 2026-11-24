import type { SectionResult } from "../../voxel/sampling/sampleGrid";

/** Ephemeral source/layer selection within one compiled snapshot. NOT a stable body ID. */
export interface DisplayFilter {
  visible: Uint8Array;
  hiddenSources: readonly number[];
  hiddenLayers: readonly string[];
}

export function sampleVisible(material: number, source: number, layer: number, filter: DisplayFilter): boolean {
  return material !== 0 && filter.visible[material] === 1
    && !filter.hiddenSources.includes(source)
    && !filter.hiddenLayers.includes(`${source}:${layer}`);
}

export function buildSectionPixels(section: SectionResult, palette: Float32Array, colorByEvent: boolean, filter: DisplayFilter, boundaries: boolean, boundaryColor: readonly number[]): Uint8Array {
  const rgba = new Uint8Array(section.w * section.h * 4);
  const shown = (i: number) => sampleVisible(section.material[i] ?? 0, section.source[i] ?? 255, section.layer[i] ?? -1, filter);
  const different = (a: number, b: number) => section.material[a] !== section.material[b]
    || section.source[a] !== section.source[b] || section.layer[a] !== section.layer[b];
  for (let i = 0; i < section.w * section.h; i++) {
    if (!shown(i)) continue;
    const key = colorByEvent ? (section.source[i] ?? 255) : (section.material[i] ?? 0);
    const edge = boundaries && ((i % section.w > 0 && shown(i - 1) && different(i, i - 1))
      || (i >= section.w && shown(i - section.w) && different(i, i - section.w)));
    for (let c = 0; c < 3; c++) rgba[i * 4 + c] = Math.round((edge ? boundaryColor[c] ?? 0 : palette[key * 3 + c] ?? 0) * 255);
    rgba[i * 4 + 3] = 255;
  }
  return rgba;
}