/** Resolve semantic CSS tokens to renderer-compatible sRGB, only after browser mount. */
export function readRenderTheme() {
  const style = getComputedStyle(document.documentElement);
  const canvas = document.createElement("canvas");
  canvas.width = 1; canvas.height = 1;
  const ctx = canvas.getContext("2d", { willReadFrequently: true });
  const color = (token: string): [number, number, number] => {
    if (!ctx) return [0, 0, 0];
    ctx.fillStyle = style.getPropertyValue(token).trim();
    ctx.fillRect(0, 0, 1, 1);
    const p = ctx.getImageData(0, 0, 1, 1).data;
    return [(p[0] ?? 0) / 255, (p[1] ?? 0) / 255, (p[2] ?? 0) / 255];
  };
  const css = (rgb: number[]) => `rgb(${rgb.map(v => Math.round(v * 255)).join(",")})`;
  return { background: css(color("--viewport")), wire: css(color("--muted-foreground")), boundary: color("--foreground") };
}
export type RenderTheme = ReturnType<typeof readRenderTheme>;