import { MATERIALS } from "../../core/materials/materials";

const hexToRgb = (h: string): [number, number, number] => [parseInt(h.slice(1, 3), 16) / 255, parseInt(h.slice(3, 5), 16) / 255, parseInt(h.slice(5, 7), 16) / 255];

/** 256×3 palette by material id. */
export function materialPalette(): Float32Array {
  const p = new Float32Array(256 * 3).fill(0.5);
  for (const m of MATERIALS) p.set(hexToRgb(m.color), m.id * 3);
  return p;
}
/** 256×3 palette by source event index (golden-angle hues), 255 = none. */
export function eventPalette(): Float32Array {
  const p = new Float32Array(256 * 3);
  for (let i = 0; i < 256; i++) {
    if (i === 255) { p.set([0.35, 0.33, 0.4], i * 3); continue; }
    const h = (i * 137.508) % 360 / 60, c = 0.75, x = c * (1 - Math.abs((h % 2) - 1)), m = 0.2;
    const [r, g, b] = h < 1 ? [c, x, 0] : h < 2 ? [x, c, 0] : h < 3 ? [0, c, x] : h < 4 ? [0, x, c] : h < 5 ? [x, 0, c] : [c, 0, x];
    p.set([r + m, g + m, b + m], i * 3);
  }
  return p;
}
export const rgbCss = (p: Float32Array, i: number) => `rgb(${Math.round(p[i * 3]! * 255)},${Math.round(p[i * 3 + 1]! * 255)},${Math.round(p[i * 3 + 2]! * 255)})`;
