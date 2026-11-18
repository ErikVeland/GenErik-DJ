# R292: Project links and credits

Erik requested GenErik DJ and PACtrack entries on the GlassCode Academy About site, with reciprocal credits.

## Published

- GlassCode Academy lists both projects at https://about.glasscode.academy/en/work. English, Bokmål and Nynorsk project pages return HTTP 200 and link to the correct public sites.
- GenErik DJ credits link to GlassCode Academy and PACtrack at https://dj.generik.au/credits.
- Browser checks confirmed the catalogue cards and GenErik DJ credits. The static website checks passed for 12 routes and 305 internal targets.

GenErik DJ deployed source: `9792f29a483d26ef0342a5ba293f8d04862ece30`.

About source: `/Users/veland/Sites/glasscode-about-r292`, commit `0962d7d`. The exact deployed security-source archive was preserved as a baseline before edits. The Linux production build and TypeScript checks passed. Both staged pages passed before switching the service. Public link checks passed in all three languages.

About release: `/opt/about-releases/0.1.1-r292-0962d7d`. The prior release remains intact. The service backup is `/etc/systemd/system/about-web.service.pre-r292`. Existing service hardening and environment settings remain in place.

## Initial PACtrack publication failure

The source at `/Users/veland/Sites/pactrack-credits-r292/.sites-checkout` contains reciprocal credits in its existing About and Transparency section. Local commit: `40ae39491d67eebc0ac8b49ed4f8fbc667a3982c`, based on `6678891b7f1491902d245251b437a344bf5f17ca`.

The protected-runtime check passed for 240 files. The required custom source build and source packaging passed. The complete dataset remains unchanged, with SHA-256 `d490ad19632b5bfdbfe13ea6cc178c37d715ca00e594d810cc2b77b1ba248d69`. The custom social cards and Worker remain part of the source build. Existing owner configuration matched the Site owner.

Sites rejected three source uploads with `artifacts_git_receive_pack_failed`, after processing seven of eight objects. Renewing access and increasing the local Git HTTP upload buffer did not resolve the failure. The local commit and generated assets are retained. No version was saved or deployed, and no assets were uploaded. Live PACtrack remains unchanged.

An earlier prebuilt package and separate publication candidate were not used. The project-specific refresh instructions require the custom source build. Retain the unused candidate at `/Users/veland/Sites/pactrack-publication-r292` as failed-path evidence, not as publication source.

## Original recovery checklist

1. Restore Sites source-upload service access for project `appgprj_6aee56dc1ae88191820164d5ac7fea53`.
2. Reconcile remote source before retrying. Preserve any newer owner changes.
3. Renew source credentials and deployment asset token as needed. Repackage the custom source build if its token has expired.
4. Push the exact source, save its matching archive, deploy, and upload the retained HTML and snapshot with the official helper.
5. Require matching asset readback, unchanged saved presentation and visible reciprocal credits before marking R292 complete.

No native app source changed. No app build or device test ran.

## Resolved in R295

PACtrack version 78 is published with both credits. The exact source upload, deployment, complete asset readback, unchanged presentation and public browser checks passed. [Resolution and evidence](website-links-r295.md#r295-pactrack-publication). The earlier failure record above remains as historical evidence.
