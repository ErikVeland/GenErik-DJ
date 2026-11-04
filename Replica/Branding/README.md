# GenErik DJ branding

`GenErik-Source.ai` preserves Erik's supplied artwork. The wordmark, font licence
and minimal master remain here. The current iPad Icon Composer document is
`../iPad/AppIcon.icon/`. Required app resources remain with their targets.

## Export icons

From the `Replica` directory, run:

```sh
swift Scripts/export-branding.swift
iconutil -c icns Branding/GenErikDJ.iconset -o Branding/GenErikDJ.icns
```

The script regenerates fallback icon sizes and previews. These outputs are
ignored. Earlier icon iterations and duplicate exports remain in the
[archive](../../docs/history.md). The iPad project compiles its current icon.
