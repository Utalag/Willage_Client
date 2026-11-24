import { useEffect, useRef, useState } from "react";
import type { WorldConfig } from "../core/coordinates/world";
import type { GeoEvent } from "../geology/events/types";
import type { TimelineQuery } from "../geology/timeline/timeline";
import type { GridResult, SectionAxis, SectionResult } from "../voxel/sampling/sampleGrid";
import { GeologyClient } from "../workers/client";

/** One cached grid and section. View-only state is deliberately absent from sampling keys. */
export function useGeologySamples(events: GeoEvent[], world: WorldConfig, res: number, query: TimelineQuery,
  mode: "3d" | "2d", axis: SectionAxis, pos: number, sectionRes: number, showSection: boolean) {
  const client = useRef<GeologyClient | null>(null);
  const [gridRecord, setGrid] = useState<{ key: string; data: GridResult } | null>(null);
  const [sectionRecord, setSection] = useState<{ key: string; data: SectionResult } | null>(null);
  const [gridPending, setGridPending] = useState(false);
  const [sectionPending, setSectionPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const gridKey = JSON.stringify([events, world, query, res]);
  const sectionKey = JSON.stringify([events, world, query, axis, pos, sectionRes]);
  const current = useRef({ gridKey, sectionKey });
  current.current = { gridKey, sectionKey };
  const gridRequest = useRef<string | null>(null);
  const sectionRequest = useRef<string | null>(null);

  useEffect(() => {
    const c = new GeologyClient();
    client.current = c;
    if (import.meta.env.DEV) {
      const target = window as Window & { __geologyRequests?: () => { grid: number; section: number } };
      target.__geologyRequests = () => ({ ...c.requests });
    }
    return () => {
      client.current = null;
      c.dispose();
    };
  }, []);

  useEffect(() => {
    if (mode !== "3d" || gridRecord?.key === gridKey || gridRequest.current === gridKey) return;
    const t = setTimeout(() => {
      const c = client.current;
      if (!c) return;
      gridRequest.current = gridKey;
      setGridPending(true); setError(null);
      c.grid({ type: "grid", events, world, res, query }).then(data => {
        if (client.current === c && current.current.gridKey === gridKey) setGrid({ key: gridKey, data });
      }).catch(e => {
        if (client.current === c && current.current.gridKey === gridKey) setError(String(e));
      }).finally(() => {
        if (gridRequest.current === gridKey) { gridRequest.current = null; if (client.current === c) setGridPending(false); }
      });
    }, 250);
    return () => clearTimeout(t);
  }, [mode, gridKey, gridRecord?.key, events, world, res, query]);

  useEffect(() => {
    if ((mode === "3d" && !showSection) || sectionRecord?.key === sectionKey || sectionRequest.current === sectionKey) return;
    const t = setTimeout(() => {
      const c = client.current;
      if (!c) return;
      sectionRequest.current = sectionKey;
      setSectionPending(true); setError(null);
      c.section({ type: "section", events, world, axis, pos, pxPerM: 1 / sectionRes, query }).then(data => {
        if (client.current === c && current.current.sectionKey === sectionKey) setSection({ key: sectionKey, data });
      }).catch(e => {
        if (client.current === c && current.current.sectionKey === sectionKey) setError(String(e));
      }).finally(() => {
        if (sectionRequest.current === sectionKey) { sectionRequest.current = null; if (client.current === c) setSectionPending(false); }
      });
    }, 200);
    return () => clearTimeout(t);
  }, [mode, showSection, sectionKey, sectionRecord?.key, events, world, query, axis, pos, sectionRes]);

  return {
    grid: gridRecord?.key === gridKey ? gridRecord.data : null,
    section: sectionRecord?.key === sectionKey ? sectionRecord.data : null,
    busy: (mode === "3d" && gridPending) || sectionPending,
    error, client,
  };
}