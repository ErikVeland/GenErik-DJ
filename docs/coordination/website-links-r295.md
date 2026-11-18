# R294 and R295: PiDay styles and project return links

Published on 18 November 2026. All seven projects in the About catalogue now link back to GlassCode Academy About.

## Public links

| Site | Link location | Result |
| --- | --- | --- |
| GenErik DJ | Credits page | Existing About and PACtrack links verified |
| PACtrack | About and Transparency | Added About and GenErik DJ credits |
| Askøy Rocketre | Existing project credits | About links verified |
| GlassCode Academy | Existing About link | Link verified |
| Epstein Files | Footer | Existing About link verified |
| PiDay | Shared footer | Added About link |
| RaceHub | Footer | Added About link |

Browser checks confirmed all seven destinations. PACtrack credits describe iPad, iPhone, iPhone Duo and Mac support.

## R294: PiDay repair

Nginx served the page from the current app but searched an older directory for its styles and scripts. All ten requested assets returned 404.

The static location now forwards requests to the active app on port 3001. Nginx configuration validation passed. All ten CSS and JavaScript assets returned HTTP 200 with the correct content types. Browser checks confirmed the restored layout and working date lookup.

Configuration evidence is in `evidence/r294`. The server backup is `/etc/nginx/sites-available/piday.glasscode.academy.conf.pre-r294`.

The repaired browser capture replaced both PiDay preview sizes on About. Source commit: `98d2bcfae434cc3e8c857cdddb7be8e487c772ed` in `/Users/veland/Sites/glasscode-about-r292`.

About release: `/opt/about-releases/0.1.1-r294-98d2bcf`. This image-only release retains the previously built application. Both public WebP files match the source bytes. Service backup: `/etc/systemd/system/about-web.service.pre-r294`.

## R295: PiDay and RaceHub

PiDay source: `/Users/veland/Sites/piday-links-r295`, commit `c0b8eef`, merged into main. The production build and TypeScript checks passed. Staged footer checks passed on the home, privacy, support and accessibility pages. Public asset and browser checks passed.

PiDay release: `/var/www/piday.glasscode.academy/releases/0.1.1-r295-c0b8eef`. The prior release remains available. The service drop-in backup is `/etc/systemd/system/piday-website.service.d/99-security-release.conf.pre-r295`.

PiDay dependency installation reported ignored optional build scripts and exited with a failure status. The subsequent production build succeeded. The dependency lockfile did not change.

RaceHub source: `/Users/veland/Sites/racehub-links-r295`, commit `845d8e3`, merged into main. The Vite production build passed for 125 modules. Browser verification confirmed the footer link.

RaceHub installation required the existing legacy peer-dependency resolution because its testing package expects a newer Pinia version. No dependency source or lockfile changed. Browser installation was skipped because the build does not require it.

RaceHub static files are deployed at `/var/www/bet.glasscode.academy`. The complete previous deployment remains at `/var/www/bet.glasscode.academy.pre-r295`. Old assets remain available. The deployed build record identifies the new commit.

## R295: PACtrack publication

Source: `/Users/veland/Sites/pactrack-r295/.sites-checkout`, commit `446a05118b1d6573ae8a2033f43f1eb21e409429`. This starts from the newer published source `e907f9892b1abce2884175aabc9a907660313581` and preserves its changes.

The source upload succeeded after removing the generated social image bundle from Git tracking. The build still regenerates this bundle and includes it in the published Worker. All source inputs remain tracked. `REFRESH.md` records this requirement. The earlier failed uploads and candidates remain preserved.

The protected-runtime check passed for 240 files. The custom source build passed for 1,135 modules. The complete dataset is unchanged: SHA-256 `d490ad19632b5bfdbfe13ea6cc178c37d715ca00e594d810cc2b77b1ba248d69`.

Published version: 78. Deployment: `appgdep_6afd31d8300c81919dedc64d5d77266b`. The matching archive is `/Users/veland/Sites/pactrack-r295.tar.gz`.

The official asset helper uploaded the complete HTML and snapshot. Readback matched both byte counts and SHA-256 hashes. The readiness check passed with four queries and 1,145 rows. The saved presentation remained identical to its pre-deployment value.

Public checks passed for the House page, Senate page and a filtered House link. Each page returned the correct server metadata and a valid 1200 × 630 PNG. Browser checks confirmed the About and GenErik DJ credits. IndexNow accepted the 88-URL submission with HTTP 200. This is submission evidence, not indexing confirmation.

Receipts are in `evidence/r295`. An initial Python HTTP check received 403. The Node check then passed all assertions. No authentication or access policy changed.

No native app source changed. No app build or device test ran. R291's separate release checks remain open.
