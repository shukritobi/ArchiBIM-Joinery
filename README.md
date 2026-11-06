# ArchiBIM Joinery

**Standalone SketchUp Ruby extension | v0.1.0 beta | SS Digital Lab**

A parametric BIM companion for [ArchiBIM](https://github.com/shukritobi/ArchiBIM), creating distinct panel-built assemblies rather than decorative single-mesh boxes.

## Available parametric families

- Base cabinets, wall cabinets, tall pantry units
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
2. Select `ArchiBIM_Joinery_v0.1.0.rbz`.
3. Enable the extension and restart SketchUp if required.
4. Open **Extensions > ArchiBIM Joinery > Joinery Manager**.

The extension can load without ArchiBIM Core; wall hosting becomes available when the main ArchiBIM extension has generated its walls. No installation changes are required to the ArchiBIM source.

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
- Native freehand Scale on cabinetry is unsupported: edit parametric dimensions instead.
- Auto-sync is in-memory and enabled by default when the plugin loads; it can be toggled in the manager. Use a copy of important models while testing.

## Manufacturing limitation

The cutlist is **preliminary only**. It is generated from real rectangular part bounding boxes, but edge-band assignments are `TBD`. Generic drawer boxes use a **13 mm per side placeholder** for slide clearance, which is **not certified for any hardware system**. Cutlists do not yet model joints, dowels, routing, hinge cup holes, 32 mm boring, machining allowance, grain, waste, optimized nesting or supplier-specific runner dimension formulas. Confirm production details before fabrication.

## Validation

Pure-Ruby core: **20 tests / 77 assertions**, all passing at first packaging. Run `ruby test/test_core.rb`. Check syntax with `ruby -c archibim_joinery/main.rb`. Build a SketchUp extension archive by running `ruby build.rb` from the repo root. GitHub Actions runs the same checks, and creates an RBZ artifact.

This prototype was **not executed inside the SketchUp desktop runtime** in the packaging environment. In-app geometry generation, GUI callbacks and hosted wall transforms must be validated in SketchUp before production use.

## License and credits

Copyright 2026 SS Digital Lab. The standalone prototype is provided for internal development and integration testing. Third-party software research informs the approach; no proprietary competitor source code or CAD components were copied.
