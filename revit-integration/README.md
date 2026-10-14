# Revit integration roadmap

The future Revit add-in will be a separately versioned C# project using a supported Autodesk Revit API version. It will import reviewed scan-derived candidates and require an operator to set levels, types, dimensions, and relationships. It must not create a claimed-as-accurate parametric BIM model directly from an unreviewed triangle mesh.

This is the final stage of **Scan → Point Cloud → Measurement → Building-element detection → Revit BIM Model**. The proposed import contract includes the source scan/cloud revision, candidate ID, approved geometry, units, project-to-Revit transform, level/type/host mapping, confidence, and reviewer decision. Persist candidate-to-Revit-element mappings for traceability and repeat-import reconciliation. Unsupported candidates remain visible for manual modeling with an explicit reason.
