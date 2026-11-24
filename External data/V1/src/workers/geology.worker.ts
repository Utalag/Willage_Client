/// <reference lib="webworker" />
import { sampleGrid, sampleSection } from "../voxel/sampling/sampleGrid";
import type { WorkerRequest } from "./protocol";

// Runs the TypeScript geological core off the main thread. This is NOT a server backend.
self.onmessage = (e: MessageEvent<WorkerRequest>) => {
  const m = e.data;
  if (m.type === "grid") {
    const r = sampleGrid(m.events, m.world, m.res, m.query);
    (self as unknown as Worker).postMessage({ type: "grid", reqId: m.reqId, result: r }, [r.material.buffer, r.source.buffer, r.layer.buffer]);
  } else {
    const r = sampleSection(m.events, m.world, m.axis, m.pos, m.pxPerM, m.query);
    (self as unknown as Worker).postMessage({ type: "section", reqId: m.reqId, result: r }, [r.material.buffer, r.source.buffer, r.layer.buffer]);
  }
};
