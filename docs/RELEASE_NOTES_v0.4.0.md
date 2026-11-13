# ArchiBIM Joinery v0.4.0 beta | 13 November 2026

## UI and workflows
- Compact sticky action dock: **Place**, **Update**, **From Lines**, **More**. Other actions, including **Eyedropper**, native Scale refresh, Draw Path, Load Selected and Resize, remain available inside More.
- Advanced / unrelated family controls are optional under Cabinet Library. The checkbox enables ordinarily inapplicable controls for unusual arrangements, but it is not a promise that the family implements them.
- Every field change, command click, JavaScript exception and selected unit is available to the UI/diagnosis reporter (best effort, bounded in-memory events plus append-only temp JSONL).

## New families
- **Suspended Basin Vanity + Mirror**: 900 W × 500 D × 550 H, 450 mm off finished floor by default; configurable 300/450 mounting, adjustable worktop and cabinet, conceptual vessel/inset basin with simplified elliptical ceramic proxy; mirror geometry, width, height, bottom datum, thickness and LED option.
- **Wall / TV Feature Panel**: 1800 W × 2400 H × **50 mm total projection** by default; adjustable overall size and depth, vertical 3 mm reveal joints, optional bottom/top/left/right LEDs with offset/size. No TV fixings or hidden support substrate calculation yet.

## Hardware / joint corrections
- Wall overhead default has **no top shadow reveal**. Tall and wardrobe have **no default top shadow reveal**.
- Tall/wardrobe doors may use **mid-height recessed groove**, 20 mm high × 10 mm deep, default centre 900 mm above finished floor. It is a represented physical geometric recess in the front (not just a graphic line). The 45° family grip moves to the bottom of wall cabinets or middle of tall cabinets, while the base keeps its top grip.
- Knob and standard bar hardware remain selectable. Confirm finger clearance and required door thickness before fabrication.

## Path generation
- Native selected edges and Draw Cabinet Path support the other Joinery family presets instead of only base/wall/tall/desk.
- Blind square corner substitute selected by family; feature panel corners use 50 mm corner closure, not a manufacturer-specific mitred cladding solution.
- Island waterfall lines are straight only. Nonorthogonal or complex joints are rejected without placing partial assemblies.
- Preserve exterior finished end panels when splitting along multiple runs.

## Eyedropper
- **More > Eyedropper · Match Settings**, or Extensions > ArchiBIM Joinery: Tools.
- Click **source**, then multiple **same-family targets**. Copies a whitelist of compatible material, face, grip, finish, carcass and internal parameters only. Preserves target type, name, UUID, absolute position, wall attachment and W/H/D/mounting. Validates replacement geometry before entering a single SketchUp undo transaction. Skips targets that cannot fit transferred construction.
- Source settings also load into the Joinery Manager editor so user may create a new matching cabinet after exiting tool.
- This is independent from ArchiBIM Core's same-type property eyedropper and does not mutate Core BIM elements.

## Diagnostics & UI logs
- **Export Diagnosis + UI Logs ZIP** creates (via save dialog):
  - `DIAGNOSIS_REPORT.txt`: readable issue listing, environment and recent events
  - `DIAGNOSIS_REPORT.json`: model group IDs, transforms, part roles, dimensions, settings and mismatch warnings
  - `UI_REPORT.txt`, `UI_REPORT.json`: UI clicks, input changes and JS errors
  - `PLUGIN_EVENTS.json`: Ruby-side event history
  - `SESSION_EVENTS.jsonl`: bounded tail from per-session persistent log
  - `SketchUp_View.png` when `write_image` succeeds
  - `README.txt` with scope and limitations
- No automatic upload. Sensitive model paths and custom cabinet names may appear in exported diagnostics; review before sharing.
- ZIP built in pure Ruby with UTF-8 headers, CRC, safe entry names and no dependencies.

## Automated checks / pending QA
- New pure Ruby v0.4 tests cover vanity mounting, basin/mirror, wall panels, top-gap regression and mid-height groove parameters.
- New eyedropper tests cover same-family whitelist, preservation of geometry/identity, mismatched type rejection and invalid target refusal.
- ZIP writer tested against regular ZIP tools and invalid path rejection.
- GitHub CI also runs earlier v0.3/core/scale/refinement tests, Ruby syntax and HtmlDialog Node JS validation.
- ArchiBIM QA Lab adds six live SketchUp 2026 test scenarios and keeps the previous v0.3 matrix.

**Not yet verified on the user’s Windows SketchUp 2026 desktop:** exact viewport joint/mitre appearance, physical finger comfort, live eyedropper pick of nested groups, actual HtmlDialog event ordering, the UI at 320-450 px width, proxy basin accuracy, manufacturing dimensions, screenshot capture and deep file reload compatibility. Source-only CI success is not a substitute for these tests.

Links:
- [SketchUp PickHelper](https://ruby.sketchup.com/Sketchup/PickHelper.html)
- [SketchUp Group](https://ruby.sketchup.com/Sketchup/Group.html)
- [SketchUp View](https://ruby.sketchup.com/Sketchup/View.html)
