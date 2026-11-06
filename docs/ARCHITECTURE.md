# ArchiBIM Joinery: system architecture & research notes

## Benchmark review (reviewed 2026-11-06)

| Product | Official link | Relevant features | Joinery response |
|---|---|---|---|
| CabinetSense (SketchUp) | https://extensions.sketchup.com/extension/7edd2253-d6e3-4603-9708-9ee9137b1b25/cabinet-sense | Dynamic component cabinetry, assembly methods, 40+ drawer systems, BOM and CNC export | Distinct part metadata and later hardware presets + CNC |
| CutCraft (SketchUp) | https://extensions.sketchup.com/extension/457bee13-61e5-431d-8bc0-f04df45c12a5/0 | Editable cabinets, drawer boxes, edge banding, cutlists | Regenerating assemblies + preliminary cutlist first; true machining later |
| CabMaker (SketchUp) | https://cabmaker32.com/products/ | Metric cabinet templates, workshop reports, part export | Metric-first templates and schedule CSV |
| EasySketch (SketchUp) | https://extensions.sketchup.com/extension/a13f69c9-e392-4de3-9ebc-eb3562f6a251/easy-sketch | Easy drag-and-drop kitchen library, appliance housings and worktops | Family-first browser and future run-layout UX |
| PolyBoard | https://boole.eu/polyboard.php | Recalculating cabinet structures, material styles, fitting links and manufacturing methods | Rule engine separated from SketchUp adapter |
| Microvellum | https://www.microvellum.com/solutions/engineering/ | Formula-based parametrics, customizable product libraries, bespoke commercial fixture modeling | Expandable construction rules, commercial template library and full documentation |

Additional manufacturing reference: Blum hardware catalogues. Each precise drawer runner variant needs its **own supplier-specific formula** and configuration. See https://publications.blum.com/2022/catalogue/en/267/.

## Ruby SketchUp module layout

```
ArchiBIM_Joinery.rb                  # SketchupExtension registration
archibim_joinery/main.rb            # SketchUp objects, tools, UI, hosted sync, CSV
archibim_joinery/core.rb            # Pure Ruby geometry math and parametric rules
archibim_joinery/ui/panel.html      # HtmlDialog, JS & CSS
build.rb                            # RBZ source packaging
.github/workflows/ci.yml            # Ruby tests and syntax validation
```

### Architecture boundary

```
SketchUp .skp
  ├── ArchiBIM core group (wall UUID; wall parameters; level)
  │      └─ dictated by ArchiBIM; Joinery reads only
  └── Joinery cabinet group (own UUID; params; optional wall UUID anchor)
         ├── nested carcass panels
         ├── nested door/drawer front panels
         ├── nested drawer box panels
         ├── nested finished panels, fillers, worktops
         └── per-part logical keys and material metadata
```

`core.rb` should remain SketchUp-independent so all parametric formulas can run in CI. Coordinates: X width, Y front-to-back, Z floor-to-ceiling, millimetres. Outer width, depth and height include fronts, finished end panels, toe kicks and worktops. Back-panel style options are inset, applied or none. Every part has a stable *logical* key, but physical SketchUp nested entity IDs regenerate when edited.

## Wall relationship contract

ArchiBIM `SSDigitalLab_ArchiBIM` data: `id, kind, length, thickness, alignment, level_id`; group transformation defines physical XY origin, X heading and floor Z. A Joinery anchor stores:

```json
{
  "wall_id": "stable-archibim-wall-uuid",
  "side": "left",
  "mode": "fixed",
  "station_mm": 100.0,
  "end_gap_mm": 50.0,
  "gap_mm": 0.0,
  "mount_height": 0.0,
  "wall_signature": "cached-serialised-wall-geometry"
}
```

Right face => cabinet local X runs along the wall start to end. Left face => its local X runs backward. In both cases local Y goes from **cabinet front to back**. The rear edge of the assembly snaps to the face (considering thickness and `alignment`). The *station* is the wall-start distance to the cabinet's occupied span, independent of visible face orientation.

Only root-level SketchUp Groups are indexed for now, matching ArchiBIM's top-level creations. A future host-adapter should use an explicit API to handle nested instance transformations, multiple levels and version compatibility.

### Bridge API proposal for ArchiBIM Core v0.8+

Introduce a **stable, versioned public integration API** without making Joinery a hard ArchiBIM dependency:

- `ArchiBIM::Integration.api_version` (integer)
- `ArchiBIM::Integration.wall_snapshot(uuid)` (world-space units + current revision)
- `ArchiBIM::Integration.subscribe(:walls_changed, &block)`
- `ArchiBIM::Integration.unsubscribe(token)`
- `ArchiBIM::Integration.hosted_element_constraints(wall_uuid)` (eventual collision/door/window data)

For atomic model updates, the main extension should provide `before_commit`/`after_commit` hooks and an explicit coordinated edit API, not mutate inside SketchUp ModelObserver. Both extensions must avoid recursive observer notifications and duplicate refreshes. Integration contract should use immutable wall ID, deleted/duplicate-host recovery, wall thickness alignment, level changes, undo/redo and tagged schema revisions.

## Next features for production maturity

1. Wall-run tool and end-to-end fill between two walls, offsets, scribes, setbacks, dual anchors and wall return/corners
2. Base sink, hob, oven, fridge, blind/diagonal corner, open-larder, dishwasher carcass, pull-out pantry
3. Wardrobe sliding doors, shoes, drawers, clothes rails and modular shelving, wall-hung TV and commercial shelving
4. Reception counters, healthcare built-ins, hospital carpentry, retail gondolas, pedestals, display bays, shopfitting
5. Door/drawer front reveal rules, inset/overlay, adjustable shelving pin rows, carcass construction joint options
6. Hardware profiles: Blum TANDEM, MERIVOBOX, LEGRABOX; Hettich, Grass, Hafele with verified manufacturer dimensions
7. Grain direction, edge banding, routing, drill patterns, fixings, cutlist, nesting, CNC export
8. ArchiBIM BIM IDs/levels/rooms, cross-referenced quantity/finish schedules, standard shop drawings and LayOut scene generation
9. Collision engine for doors, windows, columns, M&E outlets, wall reveals and minimum-clearance warnings
10. Reliable save/undo/open workflow, large-model performance tests, proper update channel and unit/locale tests

## Risk register

- Observer sync is deferred to avoid SketchUp API's explicit warning against geometry changes in transaction callbacks. This currently creates **two undo steps**.
- Real in-SketchUp tests are still required; Ruby CI cannot execute SketchUp objects or graphical event loops.
- All manufacturer joinery and runner dimensions remain indicative. Do **not** use preliminary cutlists as certified manufacturing files.
- Runtime objects are version-checked at the repository boundary; avoid silently changing published ArchiBIM `DICT` keys.