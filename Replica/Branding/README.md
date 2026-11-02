# GenErik DJ branding

The minimal icon reinterprets the original circular logo as a solid disc with
cut-out lettering and a small cue notch. It uses warm off-white and near-black.
The toolbar pairs this emblem with the app name.

`GenErik-Minimal-master.png` is the generated master. `GenErik-Source.ai`
preserves the supplied artwork. The source in Dropbox is unchanged.

## Export icons

From the `Replica` directory, run:

```sh
swift Scripts/export-branding.swift
iconutil -c icns Branding/GenErikDJ.iconset -o Branding/GenErikDJ.icns
```

The script exports all Mac icon sizes, the 1024-pixel iPad icon, and a preview.
The iPad project compiles its app-icon catalogue. The Mac packaging script copies
the icon and shared interface resource bundle into the app.
