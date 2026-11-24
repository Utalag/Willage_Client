<!-- LOVABLE:BEGIN -->
> [!IMPORTANT]
> This project is connected to [Lovable](https://lovable.dev). Avoid rewriting
> published git history — force pushing, or rebasing/amending/squashing commits
> that are already pushed — as it rewrites history on Lovable's side and the
> user will likely lose their project history.
>
> Commits you push to the connected branch sync back to Lovable and show up in
> the editor, so keep the branch in a working state.

## What Lovable manages

Rules outside this block are the project's own. Change the pieces below in
Lovable, not by hand. With the [Lovable MCP](https://mcp.lovable.dev)
connected, `send_message` asks Lovable to do it; otherwise ask the user to
use the editor.

- **Database.** Do not add or edit `supabase/migrations/` or `drizzle/`.
  Ask Lovable to change the schema.
- **Generated files.** Do not edit a file whose header says it is automatically
  generated.
- **AI gateway.** Keep model calls on Lovable's gateway, and keep
  `LOVABLE_API_KEY` out of browser code.
- **Connectors.** Lovable provides native connectors. `list_connectors` shows
  which are enabled; `add_connector` only returns the dashboard link. When a
  connector is enabled, calls go through the connector gateway and need
  `LOVABLE_API_KEY`. When Lovable does not provide one, users can bring their
  own key and store it in Secrets.
- **Secrets.** Lovable manages them. Do not put secret values in the repo.
<!-- LOVABLE:END -->

## Geology engine rules
- Engine axes are Y-up, X/Z horizontal, metres; the renderer must not convert or add geology rules.
- `src/core`, `src/geology`, `src/voxel`, `src/diagnostics` must not import React, Three.js or DOM APIs – they are the portable core for the future C# port.
- Event arrays are chronological (index 0 oldest); every deformation op implements forward/inverse/isInvertible/validate/evaluateJacobian.
- No Math.random or order-dependent state; all noise derives from integer hashes of lattice coordinates and the event seed.
- Changing an algorithm bumps its `algorithmVersion`; changing the JSON shape bumps `SCHEMA_VERSION`; update docs/geology/* with every implementation change.
- Section sampling, 2D picking and 3D plane placement share the portable section-coordinate module; this prevents axis and raster-orientation drift.
- View-only selections consume sampled material/source/layer arrays; shader clipping removes the surface without a voxel cap, so exact section pixels remain the sole displayed cut result.
- `useGeologySamples` caches a keyed grid/section and gates grid requests by 3D mode; dev-only `window.__geologyRequests()` and `window.__geologyView()` expose live counters/state for verification without changing simulation.
