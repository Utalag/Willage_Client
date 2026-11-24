import { createFileRoute } from "@tanstack/react-router";
import { GeoLab } from "../ui/GeoLab";

export const Route = createFileRoute("/")({
  ssr: false,
  head: () => ({
    meta: [
      { title: "Willage Geological Engine v0 – laboratoř" },
      { name: "description", content: "Geologická laboratoř Willage: povrchový 3D model, přímo vyhodnocené řezy v osách X/Y/Z s nezávislým rozlišením a inspekce historie bodu." },
      { property: "og:title", content: "Willage Geological Engine v0" },
      { property: "og:description", content: "Skutečný geologický evaluator, povrchový 3D model, přesné průřezy všech os a ověřovací diagnostika." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: GeoLab,
});
