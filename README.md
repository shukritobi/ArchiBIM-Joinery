# ArchiBIM Joinery

## ⬇️ Download Latest RBZ

**[Download the latest ArchiBIM Joinery SketchUp plugin (.rbz)](https://github.com/shukritobi/ArchiBIM-Joinery/releases/latest/download/ArchiBIM_Joinery_latest.rbz)**

[All releases](https://github.com/shukritobi/ArchiBIM-Joinery/releases) · [Installation instructions](#installation)

This is a permanent download link. After a successful build on `main`, GitHub Actions updates the release asset automatically. The latest version is always shown here first.

**Standalone SketchUp Ruby extension | Beta | SS Digital Lab**

A parametric BIM companion for [ArchiBIM](https://github.com/shukritobi/ArchiBIM), creating distinct panel-built assemblies rather than decorative single-mesh boxes.

## Available parametric families

- Base cabinets, wall cabinets, tall pantry units; refrigerator, oven and microwave tall housings
- Desks / workstations, wardrobes, vanities
- Bookcases, TV consoles, reception counters
- Open bays, hinged doors, drawers, or drawer-and-door combinations

Each unit is a top-level SketchUp Group. Each part is its own nested SketchUp Group tagged by role, and contains metadata. You can change overall width, height, depth; carcass/front/back/support thickness; toe kick; countertop; shelves and internal dividers; doors/drawers; applied or inset back; end panels/fillers; finishes; and optional physical backsplash.

### Recommended default dimensions

| Unit | Width | Height | Depth | Default mounting |
|---|---:|---:|---:|---:|
| Base | 600 mm | **850 mm overall including 20 mm worktop** | 600 mm | 0 mm |
| Wall | 600 mm | 720 mm | 350 mm | **1450 mm bottom**, i.e. 600 mm above 850 mm worktop |
| Tall | 600 mm | 2400 mm | 600 mm | 0 mm |
| Desk | 1200 mm | 750 mm | 600 mm | 0 mm |
| Wardrobe | 1200 mm | 2400 mm | 600 mm | 0 mm |
| Vanity | 900 mm | 850 mm | 500 mm | 0 mm |
| Bookcase | 900 mm | 2100 mm | 320 mm | 0 mm |
| TV Console | 1800 mm | 500 mm | 450 mm | 0 mm |
| Reception | 1800 mm | 1100 mm | 650 mm | 0 mm |

Core defaults: **16 mm carcass melamine**, 16 mm front, 6 mm back (independently adjustable), 100 mm toe kick, 20 mm worktop for base/vanity, 15 mm desk back support. These are **starting presets, not universal manufacturing or ergonomic standards**.

**Important distinction:** The 600 mm between 850 mm countertop and bottom of overhead cabinet is a *clear vertical gap*. It is not automatically modelled as a 600 mm material backsplash. A physical backsplash panel can be enabled separately.

## Installation

1. In SketchUp Desktop (tested target: 2026), choose **Extensions > Extension Manager > Install Extension**.
2. Select the downloaded `ArchiBIM_Joinery_latest.rbz`.
3. Enable the extension and restart SketchUp if required.
4. Open **Extensions > ArchiBIM Joinery > Joinery Manager**.

The extension can load without ArchiBIM Core; wall hosting and automatic back-to-wall orientation become available when the main ArchiBIM extension has generated its walls. No installation changes are required to the ArchiBIM source.

## Quick start

1. Open Joinery Manager and select a cabinet type.
2. Enter parameters in millimetres. **Place New Unit**, then click in the SketchUp viewport to position it. The tooltip/outline shows the envelope. Arrow keys: **Right = X**, **Left = Y**, **Up = Z**, **Down = unlock**. Escape cancels placement.
3. Select a cabinet and click **Load Selected**. Edit dimensions, press **Update Selected Cabinet** to rebuild all its parts.
4. For wall association, hold Ctrl and select **both** the cabinet and one ArchiBIM wall in SketchUp. Choose left/right exposed wall face and **fixed** or **stretch to wall end**. Press **Bind to Selected Wall**. The cabinet is snapped so its *back* touches that wall's **actual face**, based on ArchiBIM wall thickness and alignment.
5. Change the wall with **ArchiBIM's Move Connected Wall**, or edit its parameters. Hosted cabinetry auto-synchronizes after the completed SketchUp operation (using a second undo transaction). **Sync Walls** is available for manual repair.
6. Export a **BIM Cabinet Schedule CSV** or a **PRELIMINARY Cutlist CSV**.

## Integration behavior in this beta

- Reads ArchiBIM wall data directly from its published `SSDigitalLab_ArchiBIM` group attribute dictionary, including its stable wall UUID, length, level and physical face alignment.
- Joinery stores independent `SSDigitalLab_ArchiBIM_Joinery` group attributes. It **never rewrites ArchiBIM wall geometry or metadata**.
- `fixed`: wall translation/rotation preserves cabinet width and station relative to the wall start. If the cabinet no longer fits, it logs a conflict rather than silently deforming the unit.
- `stretch`: wall length changes extend/shrink the cabinet towards the wall end, respecting the initial end gap and the current panel dimensions.
- Changes are processed by a **deferred model observer** after SketchUp commits a transaction. This avoids modifying geometry from inside an observer callback.
- **Known beta limitation:** Sync uses its own undoable operation, so an ArchiBIM wall change and dependent cabinet rebuild are not yet a *single atomic undo step*. The planned versioned ArchiBIM event API will support a coordinated operation.
- In this beta, binding is supported for **root-level straight ArchiBIM walls**. Joinery cannot yet solve corner cabinets, two-wall-fit units, angled wall returns or arbitrary nested linked components.
- The plugin does **not** automatically avoid ArchiBIM windows, doors, sockets or other collisions yet.
- Native Scale now has an explicit **Refresh After Native Scale** command. It absorbs orthogonal X/Y/Z scale factors into cabinet dimensions, restores unit scale and regenerates fixed-thickness parts. Shearing or mirroring is rejected; wall-hosted refresh retains its station and uses fixed-width mode.
- Auto-sync is in-memory and enabled by default when the plugin loads; it can be toggled in the manager. Use a copy of important models while testing.

## Features introduced in v0.2.0

- **Finished panels to the floor:** fillers and visible end panels extend to the cabinet's base datum by default (`floor_finish_panels` toggle). The toe kick remains recessed.
- **Nearest ArchiBIM wall:** the back automatically aligns when placing within 350 mm of a recognized straight root-level ArchiBIM wall. Automatic orientation can be disabled; manual Bind remains.
- **Door splitting:** doors automatically distribute into equal leaves with no leaf wider than 600 mm (editable project default); configuration must remain within 12 leaves per assembly.
- **Hardware:** none, conceptual bar pull, knob or genuine 45-degree meeting-edge chamfer (door-only). Bar location defaults to 50 mm from door opening edge, vertically centered, and 128 mm nominal screw centres. Confirm actual handle supplier dimensions.
- **Kitchen appliance tall units:** fridge, oven and microwave; set nominal aperture size, opening level, side and rear clearance, plus open or closed upper storage. The back of the equipment niche is left open. These are modelling presets, **not manufacturer-approved installation dimensions**.
- **Ceiling box-up:** toggle box-up on wall, tall and appliance tall units; ceiling height uses the same floor datum as mounting height.
- **Native LayOut linework:** every generated cabinet includes separate tagged 2D front elevation and plan line groups (hidden by default until enabled in the relevant orthographic scene), in addition to dashed opening lines.
- **2D symbols:** independent `ABJ | 2D Elevation Openings` tag with dashed elevation swing indicators (tag hidden by default to keep 3D views clean).
- **DXF drawings:** export front elevation + plan for selected cabinet or batch one DXF per cabinet from **Scale & 2D Documentation**. Separate layers, mm coordinates, dashed opening swing segments. Import into CAD, or include the tagged SketchUp model in LayOut.
- **AI/MCP exchange:** export read-only JSON containing each cabinet's UUID, parameter dictionary, host ID, parts and 2D line segments. No live MCP service yet.

See [development roadmap](docs/ROADMAP.md) and [research/development log](docs/DEVELOPMENT_LOG.md) for design decisions and validation status.

## Manufacturing limitation

The cutlist is **preliminary only**. It is generated from real rectangular part bounding boxes, but edge-band assignments are `TBD`. Generic drawer boxes use a **13 mm per side placeholder** for slide clearance, which is **not certified for any hardware system**. Cutlists do not yet model joints, dowels, routing, hinge cup holes, 32 mm boring, machining allowance, grain, waste, optimized nesting or supplier-specific runner dimension formulas. Confirm production details before fabrication.

## Validation

Pure-Ruby core: **20 tests / 77 assertions** at the v0.1 baseline. v0.2 adds an independent regression suite run by CI. Run `ruby test/test_core.rb` and `ruby test/test_enhancements.rb`. Check syntax with `ruby -c archibim_joinery/main.rb` and `ruby -c archibim_joinery/runtime_ext.rb`. Build a SketchUp extension archive by running `ruby build.rb` from the repo root. GitHub Actions runs the same checks, and creates an RBZ artifact.

This prototype was **not executed inside the SketchUp desktop runtime** in the packaging environment. In-app geometry generation, GUI callbacks and hosted wall transforms must be validated in SketchUp before production use.

## License and credits

Copyright 2026 SS Digital Lab. The standalone prototype is provided for internal development and integration testing. Third-party software research informs the approach; no proprietary competitor source code or CAD components were copied.
