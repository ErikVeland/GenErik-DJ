# R293: About project previews

Published seven project previews at https://about.glasscode.academy/en/work on 18 November 2026. Each detail page has a larger preview that opens the full image.

Source: `/Users/veland/Sites/glasscode-about-r292`, commit `773057d`, merged into main. Release: `/opt/about-releases/0.1.1-r293-773057d`. The previous release and `/etc/systemd/system/about-web.service.pre-r293` remain available for rollback.

## Captures

Six previews are browser captures from the linked public sites. PACtrack displayed “Data app deployment assets are unavailable” at capture time. Its preview uses the preserved local source build from R292, with the same reviewed dataset. This task did not publish or modify PACtrack.

Original PNG captures remain in `/Users/veland/Sites/glasscode-about-captures-r293`. The About source contains 640-pixel and 1280-pixel WebP versions, totalling under 700 KB. Images load from the About host, with fixed dimensions and lazy loading.

The captures exposed inaccurate existing descriptions. Askøy Rocketre now describes its music archive, GlassCode Academy describes its learning platform, and PiDay describes date searches in pi. These corrections apply in English, Bokmål and Nynorsk. The existing unsupported case-study boilerplate is suppressed for these corrected entries.

## Verification

- Linux production build and TypeScript checks passed.
- All seven preview images returned WebP content for each of the three locale catalogues in staging.
- The larger GenErik DJ detail preview passed the staging check.
- Public browser checks confirmed the desktop catalogue, Music filter and GenErik DJ detail link.
- At a 390 × 844 viewport, the catalogue had seven previews and a 390-pixel page width, with no horizontal overflow.
- The browser viewport was reset after the check.

No native app source changed. No app build or device test ran. R292’s PACtrack reciprocal-credit publication remains open.
