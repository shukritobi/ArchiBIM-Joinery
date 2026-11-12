# ArchiBIM Joinery 0.2.0 Verification Checklist

## Automated
- [ ] Ruby syntax all files.
- [ ] Original parametric core regression suite.
- [ ] Enhancement and DXF regression suite.
- [ ] Archive RBZ; verify installable package paths.

## Desktop SketchUp 2026 (manual)
- [ ] Install RBZ using Extension Manager and open manager.
- [ ] Generate base, wall, tall, fridge, oven and microwave cabinets.
- [ ] Test filler and end-panel default to cabinet floor and optional disabled mode.
- [ ] Place 200 mm from ArchiBIM left/right straight wall; check back alignment and UUID link.
- [ ] Scale each axis (both centered and corner anchors), refresh, measure new dims, verify material thickness.
- [ ] Scale wall-hosted cabinet; confirm stable station or documented conflict.
- [ ] Check 45 degree edge profile and handles from front and perspective.
- [ ] Generate 3-door 1300 mm module and verify each leaf <600 mm.
- [ ] Toggle 2D elevation opening tag, verify dashed styles and clean perspective when tag off.
- [ ] Export all DXFs; verify AutoCAD DWG import / LayOut scene dimensions and visible swing notation.
- [ ] Export AI JSON; validate against future MCP schema.
- [ ] Undo/redo and save/reopen without losing cabinet or host metadata.
