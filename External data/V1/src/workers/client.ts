import { sampleGrid, sampleSection, type GridResult, type SectionResult } from "../voxel/sampling/sampleGrid";
import type { WorkerRequest } from "./protocol";

type Pending = { resolve: (v: unknown) => void; reject: (reason: Error) => void };
type DistOmit<T, K extends PropertyKey> = T extends unknown ? Omit<T, K> : never;
/** Main-thread facade for the geology worker; falls back to synchronous evaluation. */
export class GeologyClient {
  private worker: Worker | null = null;
  private seq = 0;
  private pending = new Map<number, Pending>();
  readonly requests = { grid: 0, section: 0 };
  readonly usingWorker: boolean;
  constructor() {
    try {
      this.worker = new Worker(new URL("./geology.worker.ts", import.meta.url), { type: "module" });
      this.worker.onmessage = (e) => {
        const p = this.pending.get(e.data.reqId);
        if (p) { this.pending.delete(e.data.reqId); p.resolve(e.data.result); }
      };
      this.worker.onerror = () => {
        for (const p of this.pending.values()) p.reject(new Error("Výpočet geologie selhal."));
        this.pending.clear();
      };
    } catch {
      this.worker = null;
    }
    this.usingWorker = !!this.worker;
  }
  private run<T>(req: DistOmit<WorkerRequest, "reqId">): Promise<T> {
    this.requests[req.type]++;
    const reqId = ++this.seq;
    const full = { ...req, reqId } as WorkerRequest;
    if (!this.worker) {
      return Promise.resolve(
        (full.type === "grid"
          ? sampleGrid(full.events, full.world, full.res, full.query)
          : sampleSection(full.events, full.world, full.axis, full.pos, full.pxPerM, full.query)) as T,
      );
    }
    const worker = this.worker;
    return new Promise<T>((resolve, reject) => {
      this.pending.set(reqId, { resolve: resolve as (v: unknown) => void, reject });
      worker.postMessage(full);
    });
  }
  grid(req: DistOmit<Extract<WorkerRequest, { type: "grid" }>, "reqId">) { return this.run<GridResult>(req); }
  section(req: DistOmit<Extract<WorkerRequest, { type: "section" }>, "reqId">) { return this.run<SectionResult>(req); }
  dispose() {
    this.worker?.terminate();
    for (const p of this.pending.values()) p.reject(new Error("Výpočet ukončen."));
    this.pending.clear();
  }
}
