import { useEffect, useRef } from "react";
import type { SectionResult } from "../../voxel/sampling/sampleGrid";

/** Draws exactly the same raster as the 3D section, without stretching or letterbox pick errors. */
export function CrossSection2D({ section, pixels, onPick }: {
  section: SectionResult | null; pixels: Uint8Array | null; onPick: (u: number, v: number) => void;
}) {
  const ref = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const cv = ref.current;
    if (!cv || !section || !pixels) return;
    cv.width = section.w; cv.height = section.h;
    const ctx = cv.getContext("2d");
    if (!ctx) return;
    const img = ctx.createImageData(section.w, section.h); img.data.set(pixels);
    ctx.putImageData(img, 0, 0);
  }, [section, pixels]);
  return <div className="flex h-full w-full items-center justify-center bg-viewport p-2 [container-type:size]">
    {section && pixels && <canvas ref={ref} aria-label="Geologický průřez" data-testid="section-2d"
      className="block h-auto max-h-full max-w-full cursor-crosshair [image-rendering:pixelated]"
      style={{ width: `min(100cqw, ${100 * section.w / section.h}cqh)`, aspectRatio: `${section.w}/${section.h}` }}
      onClick={e => {
        const r = e.currentTarget.getBoundingClientRect();
        onPick((e.clientX - r.left) / r.width, (e.clientY - r.top) / r.height);
      }} />}
  </div>;
}
