import { act, renderHook } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { DEFAULT_WORLD } from "../core/coordinates/world";
import type { GeoEvent } from "../geology/events/types";
import { createEvent } from "../geology/timeline/timeline";
import type { SectionResult } from "../voxel/sampling/sampleGrid";
import { useGeologySamples } from "./useGeologySamples";

const mocks = vi.hoisted(() => ({ grid: vi.fn(), section: vi.fn() }));
vi.mock("../workers/client", () => ({ GeologyClient: class {
  requests = { grid: 0, section: 0 };
  grid = mocks.grid;
  section = mocks.section;
  dispose() {}
} }));

const events: GeoEvent[] = [createEvent("sedimentation", "s")];
const query = {};
function result(pos: number, pxPerM = 4): SectionResult {
  return { w: 64 * pxPerM, h: 64 * pxPerM, axis: "z", pos, pxPerM,
    material: new Uint8Array(0), source: new Uint8Array(0), layer: new Int32Array(0), evalMs: 0 };
}
const initial = { mode: "3d" as "3d" | "2d", pos: 32, sectionRes: 0.25, res: 2, events };
const hook = (p: typeof initial) => useGeologySamples(p.events, DEFAULT_WORLD, p.res, query, p.mode, "z", p.pos, p.sectionRes, true);
async function tick() { await act(async () => { await vi.advanceTimersByTimeAsync(300); }); }

beforeEach(() => {
  vi.useFakeTimers(); mocks.grid.mockReset(); mocks.section.mockReset();
  mocks.grid.mockResolvedValue({ res: 2 });
  mocks.section.mockImplementation((req: { pos: number; pxPerM: number }) => Promise.resolve(result(req.pos, req.pxPerM)));
});
afterEach(() => { vi.useRealTimers(); });

describe("Sampling request separation", () => {
  it("moving a section samples only the plane, never the whole volume", async () => {
    const { rerender, result: live } = renderHook(hook, { initialProps: initial });
    await tick(); expect(mocks.grid).toHaveBeenCalledTimes(1); expect(mocks.section).toHaveBeenCalledTimes(1);
    rerender({ ...initial, pos: 23.375 }); await tick();
    expect(mocks.grid).toHaveBeenCalledTimes(1); expect(mocks.section).toHaveBeenCalledTimes(2);
    expect(live.current.section?.pos).toBe(23.375);
  });
  it("changing section resolution does not change 3D sampling", async () => {
    const { rerender } = renderHook(hook, { initialProps: initial }); await tick();
    rerender({ ...initial, sectionRes: 0.5 }); await tick();
    expect(mocks.grid).toHaveBeenCalledTimes(1);
    expect(mocks.section).toHaveBeenLastCalledWith(expect.objectContaining({ pxPerM: 2 }));
  });
  it("2D model edits never sample a grid, and returning to a cached 3D model reuses it", async () => {
    const { rerender } = renderHook(hook, { initialProps: { ...initial, mode: "2d" } }); await tick();
    expect(mocks.grid).not.toHaveBeenCalled();
    const changed = [...events, createEvent("fold", "f")];
    rerender({ ...initial, mode: "2d", events: changed }); await tick();
    expect(mocks.grid).not.toHaveBeenCalled(); expect(mocks.section).toHaveBeenCalledTimes(2);
    rerender({ ...initial, events: changed }); await tick(); expect(mocks.grid).toHaveBeenCalledTimes(1);
    rerender({ ...initial, events: changed, mode: "2d" }); await tick();
    rerender({ ...initial, events: changed }); await tick(); expect(mocks.grid).toHaveBeenCalledTimes(1);
  });
  it("a rerender with unchanged geology/view keys does not resample", async () => {
    const { rerender } = renderHook(hook, { initialProps: initial }); await tick();
    rerender({ ...initial }); await tick();
    expect(mocks.grid).toHaveBeenCalledTimes(1); expect(mocks.section).toHaveBeenCalledTimes(1);
  });
  it("an older asynchronous section cannot replace the new plane", async () => {
    let first: ((s: SectionResult) => void) | undefined;
    mocks.section.mockImplementationOnce(() => new Promise<SectionResult>(resolve => { first = resolve; }));
    const { rerender, result: live } = renderHook(hook, { initialProps: initial }); await tick();
    rerender({ ...initial, pos: 23.375 }); await tick();
    expect(live.current.section?.pos).toBe(23.375);
    if (!first) throw new Error("First request missing");
    await act(async () => { first?.(result(32)); });
    expect(live.current.section?.pos).toBe(23.375);
  });
});