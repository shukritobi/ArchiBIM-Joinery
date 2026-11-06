# SketchUp 2026 acceptance checklist

Use a disposable `ArchiBIM_Joinery_Test.skp` before touching any live project.

- [ ] Install the RBZ via Extension Manager, confirm Joinery Manager appears under Extensions
- [ ] Place Base 600×850×600 and inspect separate named 16 mm carcass groups, 20 mm worktop, 100 mm toe kick
- [ ] Confirm toe kick is recessed from the front, not placed at the back
- [ ] Change carcass thickness to 18 mm. Left/right sides, internal bottom, back width and shelves update, and total outside width stays unchanged
- [ ] Change base from doors to 3 drawers, inspect separate nested front / box / bottom pieces
- [ ] Place wall unit and confirm mount 1450 mm above clicked point, matching 600 mm clear gap above base 850 mm worktop
- [ ] Place Desk 1200×750×600, change support thickness 15 → 20 mm
- [ ] Check all 9 family presets generate without SketchUp Ruby Console errors
- [ ] Check arrow placement inference locks: Right=X, Left=Y, Up=Z, Down=unlock
- [ ] Create ArchiBIM wall with thickness 150 mm and center alignment; Ctrl-select cabinet and wall and bind to LEFT face
- [ ] Confirm cabinet back sits at +75 mm wall physical face; repeat RIGHT face at -75 mm and verify opposite room placement
- [ ] Bind in FIXED mode, move ArchiBIM wall 300 mm via Move Connected Wall, confirm cabinets relocate but do not resize
- [ ] Bind in STRETCH mode, change host wall length +400 mm, confirm cabinet expands according to its end gap and each panel recalculates
- [ ] Make wall too short to host the cabinet, ensure error is logged and cabinet does not silently deform
- [ ] Detach, move wall and confirm detached cabinet does not follow
- [ ] Export BIM Schedule CSV and Preliminary Cutlist CSV; verify dimensions and metadata
- [ ] Save SKP, close and reopen, confirm all parameters + wall IDs survive and continue syncing
- [ ] Undo/redo wall edits. Observe separate sync undo entry in this beta; ensure no infinite observer loop
- [ ] Duplicate a cabinet and confirm the automatic synchronization scan repairs duplicated logical cabinet IDs, with no duplicate values in the BIM schedule
- [ ] Test visibility/tags and selection, mixed ArchiBIM and Joinery assemblies, rotation and wall alignment
- [ ] Stress test 100 cabinets, editing and wall syncing without runaway model lag

Log any exception using **Window > Ruby Console** with exact reproduction steps, SketchUp version, screenshots and relevant group properties. Do not validate by visual appearance alone; compare millimetre dimensions using Tape Measure/Dimension.
