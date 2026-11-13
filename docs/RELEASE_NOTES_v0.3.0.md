# ArchiBIM Joinery v0.3.0 beta | 13 November 2026

## Delivered

- **Island / breakfast bar:** new standalone unit (default 1800 W × 600 D × 1000 H mm, 50 mm worktop), open or carcass-based. One 45° waterfall is the default. Independently enable left/right waterfall; worktop and floor-to-top legs use matching actual mitred section profiles and separate BOM parts. Open islands can use a 200 mm low back, a 200 mm top apron, full rear panel, or no back. Support and finishes are independently modelled. A waterfall slab is NOT assumed to be structural.
- **Blind corners:** corner base, overhead, tall and desk families, with twin perpendicular 50 mm face returns (adjustable) and access from front, perpendicular return, or none (empty/blind).
- **Native line paths:** select connected native edges on one horizontal plane, or draw a new polyline with cursor inference. Path alignment = back/front/centre and orientation = cabinet back on path left/right. The planner distinguishes concave versus convex 90° corners, trims intersecting inside ends and fills outside corner spaces with separate square blind-corner assemblies. Unsupported non-90° joints, branched networks and closed loops fail early with messages. Long legs split into separate root cabinets. A path is committed in one undoable transaction, with a new unique UUID for each root.
- **Overhead units:** base paths generate separate 720 H × 350 D overhead cabinets by default, mounted at 1450 mm, retaining their own independent root groups and settings.
- **Modular carcass:** root cabinet widths over 1200 mm are broken into separate panel-set modules (twin end sides at the join), including independent top/bottom/back/shelf parts. Splits seek door reveals; drawers are regenerated per cabinet module. 1200 mm is a selectable upper bound, not an instruction that every bay must be 1200 mm.
- **Handle adjustments:** base presets have no protruding hardware, a 20 mm upper reveal, and two finished 20 mm? **Correction:** finished end panel thickness follows the user-configured `panel_thickness` (16 mm by baseline unless changed), not a hardcoded 20 mm. The 45° handle profile now bevels the **rear face of the top edge** so the outer front lip is preserved.
- **Manager UI:** added island and corner families, waterfall checkboxes, back/construction selectors, line alignment, corner access, module width and one-click Generate From Selected Lines / Draw Cabinet Path commands.

## Construction research and modelling limits

- [Cosentino Sensa design and installation guide](https://assetstools.cosentino.com/api/v1/bynder/doc/FCD7589A-B7C3-4FF9-8CA096519D1223F0/sensa-guide-for-design-and-installation-of-quarzite-and-granit.pdf?dl=sensa-guide-for-design-and-installation-of-quarzite-and-granit.pdf): mitered waterfall connections require support and manufacturer-specific adhesive and overhang criteria. The model does not certify slab strength, adhesive or support design. The default 50 mm surface is a **design parameter**, not a manufacturer recommendation for natural stone thickness.
- [Cabjaks corner-cabinet guidance](https://cabjaks.co.nz/blogs/training/tips-for-working-with-corners): 50 mm field-trimmable blind-corner fillers are a common starting detail, but hardware and obstruction clearances vary.
- [Cabinets.com frameless blind-corner guide](https://www.cabinets.com/media/download/euro-base-blind-details.pdf): 3-inch filler recommended with some perpendicular drawer/hardware configurations. Do not assume 50 mm is always sufficient.
- [ProCraft 2026 blind-corner technical spec](https://content.app-sources.com/s/90786209979408084/uploads/Resources/ProCraft_Cabinetry_Spec_Book_Slides_GL4.1.2026-5248754.pdf): 1.5-inch minimum filler in its illustrated hardware-specific corner scenario; not a universal requirement.
- SketchUp official [InputPoint](https://ruby.sketchup.com/Sketchup/InputPoint.html), [Tool](https://ruby.sketchup.com/Sketchup/Tool.html) and [View](https://ruby.sketchup.com/Sketchup/View.html) API contracts inform path drawing, inference and preview.

## Test coverage

`ruby test/test_layout.rb` covers island configurations and mitre metadata, corner fillers/access, door-free reveals, 1200 mm carcass segmentation, modular drawer rows, concave/convex right-angle joining, edge order recovery, back/centre/front reference, 3D plane validation and rejected invalid turns. CI also runs all existing core/enhancement/refinement/scale/copy tests, full Ruby syntax, HTML JavaScript syntax and RBZ packaging.

**Desktop acceptance remains unverified:** on SketchUp 2026 Windows, test generated groups and transforms, interior/exterior corner joins, 45° miter visual fit and materials, actual shadow-line finger access, panel hierarchy and cutlist, native edge selection, the interactive path tool, keyboard inference, multiple paths, cabinet/module selection, upper-unit mounting, undo/redo, and older model compatibility. Spot check LayOut/DXF linework for path-joined cabinets.

## Known beta constraints

1. Orthogonal (90°) path joins only. Other angles, branches, self-intersections, closed loops and nested-edited source geometry are not yet supported.
2. A generated corner is a simple **blind square corner** with two perpendicular returns. Lazy Susan trays, hinge opening angles, hardware-specific blind pull-out mechanisms, true two-wall hosting and corner-specific CNC machining are future work.
3. Parametric native Scale repair remains the separate explicit Refresh command; this release does not claim to solve all SketchUp Scale cases.
4. Source lines stay native SketchUp edges. Generated cabinetry is a snapshot of the path, not continuously linked to future edits of the original edges.
5. Worktop profiles depict a 45° mitred design intent, not fabricator-approved stone fabrication, surface grain matching or safe overhang engineering.
6. Full manufacturing cutlists, edge banding, 32 mm hole system, fasteners and hardware clearances still require supplier sign-off.

**Status:** code branch and CI validation; SketchUp UI/geometry QA pending. Do not mark desktop acceptance passed without captured in-app evidence.
