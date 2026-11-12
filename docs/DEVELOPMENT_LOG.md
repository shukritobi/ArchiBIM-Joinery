# Development Log

## 2026-11-12: v0.2.0 feature implementation
**Base:** v0.1.0, unchanged parameter schema version 1 for backward compatibility.
**Repository:** shukritobi/ArchiBIM-Joinery.

### Research reviewed
- SketchUp Ruby API: ComponentInstance transforms, Model#raytest,
  Layer#line_style and tags. Official:
  https://ruby.sketchup.com/Sketchup/ComponentInstance.html
  https://ruby.sketchup.com/Sketchup/Model.html
  https://ruby.sketchup.com/Sketchup/Layer.html
- Revit 2D symbolic line strategy / view-specific family representation:
  https://help.autodesk.com/cloudhelp/2025/ENU/Revit-Model/files/GUID-4949A893-E556-4426-AE1D-0BC3C90BF672.htm
- Autodesk door swing display controls:
  https://help.autodesk.com/cloudhelp/2025/ENU/AutoCAD-Architecture/files/GUID-1F834C86-8CC0-4D41-A73A-6EE2132D0E3C.htm
- LayOut/SketchUp CAD export:
  https://help.sketchup.com/en/layout/exporting-or-printing-your-layout-document
  https://help.sketchup.com/en/sketchup/importing-and-exporting-cad-files
- IKEA Malaysia appliance housing and ventilation:
  https://www.ikea.com/my/en/p/metod-high-cabinet-f-built-in-appliances-white-10270968/
  https://www.ikea.com/my/en/p/metod-top-cabinet-with-ventilation-white-40271004/
- Bosch ventilation/installation constraints:
  https://www.bosch-home.com/qa/en/products/fridges-freezers/fridges/02_fridges_tab3_installation_faq
- Integrated appliance housing design (600 mm width, back recess):
  https://a.storyblok.com/f/84703/x/9486783230/assembly_kitchen_fh-series_eng.pdf
- Hardware offset and CTC practices:
  https://plankhardware.com/blogs/tea-break/where-to-place-cabinet-hardware-guide
  https://www.factorydirecthardware.com/pages/cabinet-pulls-how-to-choose-center-to-center
- Microvellum CAD, hardware reporting and manufacturing workflow:
  https://www.microvellum.com/solutions/reporting
  https://www.microvellum.com/closet-design-and-manufacturing-software-for-autocad

### Decisions
1. Do not directly scale every panel's geometry when refreshing a native Scale transform.
   Normalize world transform and regenerate with same configured thicknesses and gaps.
2. No guessed standard for ventilation or electric appliance fit: allow parametric nominal
   cavity clearances, mark all as preliminary, and defer make/model approval.
3. Treat cabinet door max width 600 mm as default project rule, not an industry law.
4. Preserve self-contained module: absence of ArchiBIM Core is not fatal;
   auto-orientation activates only for recognized ArchiBIM wall UUIDs.
5. Do not write changes into ArchiBIM's wall metadata.
6. Export DXF via pure-Ruby R12 text (mm), compatible with AutoCAD;
   retain native SketchUp tagged symbols for LayOut workflows.
7. Read-only JSON is an AI/MCP interchange format; the live MCP server is scheduled later.

### Changes
- Added `archibim_joinery/enhancements.rb`: cabinet defaults, appliance families,
  finished panels, auto door segmentation, knobs/bars/45-degree profiles, box-ups,
  nearby straight-wall candidate detection.
- Added `archibim_joinery/drafting.rb`: front elevation and plan segments, layered
  dashed-line DXF R12 generator, size annotations and mm coordinates.
- Added `archibim_joinery/runtime_ext.rb`: geometry bevel and opening-symbol groups;
  closest ArchiBIM wall binding on new placement; Refresh After Scale;
  single/batch cabinet DXFs; AI/MCP JSON export.
- Updated HtmlDialog manager and registered handlers; updated extension and packaging version.
- New regression tests and CI for all test files.
- Added roadmap and research/development logs.

### Still to validate
- GitHub Actions CI run and installable RBZ artifact generated successfully.
- Runtime testing in actual SketchUp 2026 desktop (this environment has no SketchUp GUI).
- Exact behavior of tag dashed-line display in LayOut; DXF opening line style roundtrip.
- Extending appliance families to manufacturer approved installation geometry,
  fabrication-grade handles and drilling positions.
