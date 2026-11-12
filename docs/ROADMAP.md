# ArchiBIM Joinery Development Roadmap
Last reviewed: 2026-11-12. Companion to [ArchiBIM Core](https://github.com/shukritobi/ArchiBIM).

## Vision
One parametric source of truth for interior built-ins: (a) SketchUp 3D joinery geometry,
(b) 2D elevation/plan/sections suitable for LayOut and DXF, (c) part schedules,
(d) hardware and manufacturer-specific details, and (e) safe tool-mediated MCP/AI workflows.
Joinery owns its cabinet model, and ArchiBIM Core owns the building walls.

## v0.1.0 baseline
Completed: nine joinery families; panel-based geometry and metadata; selectable cabinet
parameter editor; manual stable-ID hosting to root ArchiBIM straight walls; wall
re-synchronization; preliminary cutlist and cabinet CSV. Known caveats: group transforms
and GUI behavior not tested in an actual SketchUp 2026 desktop runtime.

## v0.2.0 research-led development (2026-11-12)
Status below refers to repository code and pure-Ruby tests, **not** desktop certification.

| Request | Status | Implementation / limitation |
|---|---|---|
| 1. Floor-length fillers and end panels | Implemented in engine | floor_finish_panels defaults true. Does not extend wall-unit panels below the unit's mounting datum: local floor means cabinet-local base, not building zero. Verify finish detail on site. |
| 2. Back to nearest wall on placement | Beta | auto_wall_orient defaults true, finds nearby **root-level ArchiBIM straight walls** using face offset and aligns back; within 350 mm of click; explicit bind remains. Collision/obstacle avoidance and ambiguous corner resolution remain planned. |
| 3. Dashed elevation opening indicators | Beta | Non-solid tag ABJ \\| 2D Elevation Openings (off by default) and DXF dashed layer for hinged doors. Elevation symbols generated from each leaf. Scene-based visibility still needs SketchUp testing. |
| 4. Non-destructive native Scale + Refresh | Beta | Reads actual X/Y/Z transform scale on selected cabinet; updates width/depth/height, resets transform, rebuilds from fixed material thickness. Reject shear/mirror/invalid dimensions. Hosted Scale keeps wall anchor and changes stretch mode to fixed. Continuous real-time regeneration is future work. |
| 5. Auto door leaves no wider than 600 mm | Implemented in engine | 600 mm maximum with auto_doors true; evenly divide opening. Reject >12 leaves, prompt module split. Custom max supported. |
| 6. Handles and 45-degree variant | Beta | none, bar, knob, edge_45; vertical bar at 50 mm from meeting edge and mid-height; 128 mm nominal screw-centre parameter; simple conceptual hardware solids and true door-edge bevel geometry. Hardware shop geometry, holes, material choice and specialized cuttings still pending. |
| 7. Kitchen appliance families | Beta | fridge_tall, oven_tall, microwave_tall, adjustable niche W/H/Z and side/rear clearances; open/door upper storage; protected open niche back; lower doors for oven/microwave. Appliance-specific support, load, fire resistance, hinging, air duct routing and removable ventilation grille remain unimplemented. |
| 8. Ceiling box-ups | Implemented in engine | wall, tall and appliance tall families; ceiling_height and box_up option; box-up independent of carcass. Sloped ceilings and obstructions planned. |
| 9. 2D plans and elevations | Beta | one DXF per selected cabinet or batch, with separately layered mm plan/elevation lines and dashed door swings; tags available for LayOut views. Each cabinet also contains native SketchUp 2D elevation and plan line groups, hidden on separate tags until enabled in orthographic scenes. No shop-ready dimensions, sections, annotations, fabrication holes or .layout document generation yet. |
| 10. MCP / AI integration | Foundation | Export read-only structured JSON for ID, family, parameters, wall host, parts and linework. **Not an MCP server** and no autonomous write tools yet. |

## Next releases
### v0.2.1  Desktop validation and hardening (priority)
- SketchUp 2026 tests: actual placement and nearest wall orientation, end panel floor levels,
  native Scale handles from center/corner and moved pivot, normal + rotated wall binding,
  scene visibility, LayOut vector and DXF import into AutoCAD, uninstall/reinstall.
- Add smoke test SKP fixtures and screenshots per family, manual checklist and crash log export.
- Improve wall detection by explicit host selection, walls inside nested groups, back-face
  clearance probing, obstacle rejection and side consistency at corners.
- Formalize opening symbols for paired/odd doors and visual dash style.

### v0.3.0 Kitchen and appliance detail
- Manufacturer-specific configuration templates for refrigerator/oven/microwave dimensions,
  ventilation cross-sectional free area, plinth grille and air flow path, hinge systems,
  weight/heat constraints, kitchen plinth interface, and extra appliance types.
- Sink/dishwasher/hood/hob, corner and angled units, 3D hardware library and
  drilling patterns; slab/shaker/laminated/45-degree routed grip variants.
- Proper box-up finishing against ceiling and soffit obstructions.

### v0.4.0 Professional documentation
- Shop drawings: section views, per-panel orthographic projections, dimension chains,
  title blocks, tags, levels, door swings, appliance clearances, hardware locations.
- LayOut-oriented scenes per cabinet and run with saved styles/tag visibility.
- Stable DXF/R2013+ exporter with annotations, polylines, arcs and hatch; DWG via
  SketchUp/LayOut native export; verified true-scale round trip.
- Schedule revision tracking and multi-cabinet sets.

### v0.5.0 Fabrication and schedules
- Manufacturer hardware families (hinges, slides, brackets, pulls), boring patterns,
  grain/edge-banding, cut optimization and CNC outputs.
- Validate material sheets and woodshop tolerances; BOM and estimates from part metadata.

### v0.6.0 ArchiBIM + MCP automation
- Stable versioned ArchiBIM event bridge to replace deferred second undo transaction.
- MCP server tools with schema validation, approval and deterministic undo operations:
  list_cabinets, inspect_cabinet, create_cabinet, update_parameters,
  bind_to_wall, regenerate_drawings, export_schedule, validate_model.
- Local-only transport by default, explicit access controls, per-command audit logs.
- Collision detection with walls, openings, equipment and other built-ins;
  automatic room-based cabinetry and revision-safe downstream drawing refresh.

## Completion standards
A feature is ready only when pure-Ruby tests, SketchUp 2026 integration,
3D/2D visual review, DXF scale validation and regression tests all pass.
No preliminary cutlist or symbolic appliance clearance is fabrication approval.
