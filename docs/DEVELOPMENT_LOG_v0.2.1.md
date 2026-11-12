# Joinery v0.2.1 beta: Desktop QA fixes (12 Nov 2026)

Triggered by annotated SketchUp 2026 screenshots and failed native-scale / hardware checks.

## Implemented
- **Scale:** preserve native SketchUp Group transform rotation and world origin, absorb committed X/Y/Z scale into parametric overall width/depth/height, normalize the outer Group transform, regenerate panels from configured millimetre thicknesses. Refuse mirrored and skewed transforms. Guard Update Selected when unresolved scale exists. Add reliable top-of-panel \`Resize to W / D / H\` path independent of native Scale. Runtime validation is still pending.
- **UI:** sticky creation/edit/resize toolbar at the top; irrelevant settings grey out instead of disappearing. Check \`Allow advanced / normally irrelevant controls\` to override. Preserve all options when switching between cabinet families.
- **Door grips:** 45-degree grip is now a continuous **horizontal top-edge bevel**, separated from the overhead horizontal by 20 mm shadow reveal, not on vertical meeting edges. Drawer fronts also accept top bevel.
- **Hardware:** cylindrical bar pulls with round stalks and circular knobs (SketchUp revolved/polygon-extruded approximations at 32–40 segments, not vendor-native objects).
- **Drawer tiers:** configurable \`drawer_shadow_gap\`, default 20 mm, equal between tiers and at the top of the stack. Supports combo family.
- **Drawer runners:** none / generic / ball-bearing side mount / indicative Blum MOVENTO / indicative Hettich Quadro; adjustable nominal length and clearance. Slide outlines are shown as separate parts and plan symbols. Hardware is excluded from preliminary sheet cutlist.
- **2D drawing:** front elevation outlines, drawer tier top edges, dashed drawer pull chevrons and representative drawer-tray/runner plan lines in SketchUp tagged drawing groups and AutoCAD-friendly DXF layers.
- **Countertop skirting:** optional rear countertop skirting; 50 mm default adjustable 0–200 mm using slider, thickness inherited from countertop thickness.

## Desktop-only tests still required
1. Confirm native Scale grip with nonuniform scaling produces a group transformation in SketchUp 2026.
2. Finish Scale tool before clicking Refresh; verify world origin is preserved for center and corner grip variants.
3. Verify direct W/D/H numeric resize behaves correctly on hosted and unhosted cabinets, plus undo/redo.
4. Check horizontal bevel and circular hardware in shaded, hidden-line and section views.
5. Check drawer shadow gaps 20 mm at all tiers and top and inspect plan/elevation linework in LayOut and AutoCAD.
6. Verify v0.2.1 upgrades existing cabinets without breaking parameter data / installations.

## Research and constraints
- SketchUp official API: transformations, native Group transform and model-transaction observer lifecycle.
  https://ruby.sketchup.com/Geom/Transformation.html
  https://ruby.sketchup.com/Sketchup/Group.html
  https://ruby.sketchup.com/Sketchup/ModelObserver.html
- SketchUp entity creation for curved hardware faces:
  https://ruby.sketchup.com/Sketchup/Entities
- Blum MOVENTO width planning (internal drawer width = cabinet opening minus 42 mm):
  https://ea.blum.com/en/building-a-movento-drawer/
- Blum runner system original installation documents:
  https://www.blum.com/my/en/products/runnersystems/tandem/downloads-videos/
- Hettich Quadro IW and installation guidance:
  https://hta.hettich.com/en-au/runner-systems/quadro/quadro-25/faq

Dimensions and rail models are indicative. Use exact SKU cut sheets before fabrication.

## Suggested next development
- Better native Scale interception by a dedicated tool and per-cabinet observer-based diagnostic traces (see separate QA lab).
- Manufacturer-approved runner, drill-hole and hinge libraries; Gola aluminium channel and integrated handleless construction.
- Front-specific skirting support and generated fully dimensioned shop drawings (including sections and schedules).
