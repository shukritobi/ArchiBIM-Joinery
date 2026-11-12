# ArchiBIM Joinery v0.2.0 release verification (12 Nov 2026)

CI must pass syntax checks, original 20 regression cases, new parametric and DXF regression suite, and build RBZ. Until desktop testing is complete, release is beta.

## SketchUp 2026 desktop acceptance
- [ ] Install RBZ through Extension Manager, reboot SketchUp and open manager.
- [ ] Generate base, wall, pantry, fridge, oven, and microwave units.
- [ ] Fillers and finished end panels touch unit datum by default; toe kicks remain recessed.
- [ ] Near-wall placement positions cabinet's back to both physical ArchiBIM wall faces, including rotated walls.
- [ ] Scale X, Y, Z separately; Refresh restores thicknesses and the 3D envelope.
- [ ] Confirm automatic max door leaf width 600 mm with 1200, 1300 and 2000 mm widths.
- [ ] Door bar, knob and 45-degree edge handle geometry, offsets and material groups.
- [ ] Fridge opening, ventilation requirements and upper-open/closed option; oven/microwave cavities.
- [ ] Wall and tall box-up ceiling closure.
- [ ] Enable native 2D elevation/plan tagged groups in orthographic LayOut model scenes, verify true-scale linework.
- [ ] LayOut front projection displays dashed opening markers on dedicated tag.
- [ ] AutoCAD imports exported DXF in millimetres and layers preserve opening line style.
- [ ] JSON data export contains IDs, parameters, parts and 2D linework.
- [ ] Undo, save, reopen and subsequent edit preserve metadata and visual correctness.

Not certified for shop production; check manufacturer clearance, ventilation and hardware.
