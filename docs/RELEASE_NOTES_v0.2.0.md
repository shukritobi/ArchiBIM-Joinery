# ArchiBIM Joinery 0.2.0 (beta)

Released: 2026-11-12

## Changes
- Fillers and exposed end panels now extend down to the cabinet mounting datum/floor by default, with opt out.
- On placement, auto-detect and snap back onto nearby straight root-level ArchiBIM walls.
- Add native grouped 2D plan and front elevation linework on hidden-by-default tags for SketchUp/LayOut; dashed swing linework for door fronts.
- Add post-native-Scale "Refresh" to preserve panel/material thickness while applying axis-scaled overall dimensions.
- Auto divide hinged door openings into evenly sized leaves maximum 600mm each.
- Cabinet handles: none, integrated 45deg door edge bevel, knob, and placeholder store-bought bar pull with 50mm meeting-edge offset and vertical center.
- New refrigerator, oven and microwave tall kitchen units with adjustable clear openings and optional upper storage.
- Ceiling-height box-up option on tall and wall units.
- Selected/batch per-cabinet 2D DXF export and read-only AI/MCP JSON exchange format.

## Verification
- Ruby 3.3 parameter and drafting tests: 28 cases, 122 assertions passed as of CI run 43127966022 (before final LayOut tag changes).
- Actual SketchUp desktop and LayOut visual testing remains **not completed**; this is an experimental beta.
- Appliance cutouts, ventilation, fire/heat ratings, hardware positions, finish manufacturing and DXF drawing dimensions are preliminary, not manufacturer specifications.

## Upgrade
Install `ArchiBIM_Joinery_v0.2.0.rbz` from the GitHub Actions workflow build via SketchUp Extension Manager.
For exact feature limitations and future milestones see ROADMAP.md and DEVELOPMENT_LOG.md.
