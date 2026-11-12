# ArchiBIM Joinery v0.2.1 beta

### Fixes from SketchUp 2026 screenshots
- Preserve parametric cabinet panel thickness when adopting committed native Scale through **Refresh Native Scale**.
- Added **Resize to W / D / H** as an independent reliable numeric resize path.
- Protect **Update Selected** from operating while the selected outer cabinet still has a native scale transform.
- Sticky create / update / resize controls at the top of the Joinery manager.
- Disable/grey irrelevant cabinet-family fields without removing advanced or cross-family options.
- Move the integrated 45-degree grip to the horizontal top edge below a 20 mm shadow reveal.
- Model round knobs and cylindrical bar pulls.
- Equal tier shadow gaps for drawer fronts, default 20 mm.
- Drawer runner families with indicative Blum MOVENTO and Hettich Quadro profiles, adjustable clearances and nominal lengths.
- DXF and native SketchUp drawing linework for drawer projections and pull symbols.
- Optional countertop rear skirting/upstand, default 50 mm, with a height slider and countertop-matched thickness.

### Testing
Ruby parameter, scale-math and drawing tests run in GitHub Actions. Requires manual desktop confirmation in SketchUp 2026 and LayOut.

Manufacturing drawing and runner measurements are preliminary only. Confirm against product-specific installation sheets.

See [v0.2.1 development notes](docs/DEVELOPMENT_LOG_v0.2.1.md).
