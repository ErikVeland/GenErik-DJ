# GenErik DJ website

Canonical origin: https://dj.generik.au

The site is static HTML and custom CSS. It requires no JavaScript runtime, browser storage or external font service.

## Build and check

```sh
python3 website/build.py
python3 website/tests/check_site.py
python3 website/serve.py
```

Open http://127.0.0.1:4318 for local review. The build uses Python's standard library and does not access the network.
Edit pages in `content/`, styling in `assets/site.css` and product identity in `site.json`.
Keep development claims separate from release-approved features.

## Public App Store fields

| Field | URL |
| --- | --- |
| Marketing | https://dj.generik.au/ |
| Support | https://dj.generik.au/support |
| Privacy policy | https://dj.generik.au/privacy |
| Privacy choices | https://dj.generik.au/privacy/choices |
| Accessibility | https://dj.generik.au/accessibility |

Do not add an App Store badge until the actual public listing exists.
App Store Connect field changes are separate from website publication.
The app purchase page now points at the canonical privacy route. No app build was made for this website task.

## Assets

Images are derived from genuine, historical iPad test captures. `image-provenance.json` records the source hashes.
`prepare_assets.py` creates responsive WebP/JPEG assets and social artwork. It requires Pillow, FontTools, Brotli and the original ignored test captures.
Normal site builds use the committed assets and do not require those captures or Pillow.
Archivo is self-hosted under the included SIL Open Font License. Its Latin subset preserves variable weight and width data.
Application notices retain the supplied licence text verbatim.

## Hosting

The Glasscode server serves `/var/www/generik/current` through a dedicated Nginx virtual host.
Versioned folders in `/var/www/generik/releases` preserve prior deployments.
`deploy/nginx.conf` contains the production virtual host. `deploy/http-bootstrap.conf` is only for initial certificate issuance.
DNS must point `dj.generik.au` at the Glasscode server. The certificate uses the existing Certbot webroot and scheduled renewal.
The legacy Glasscode hostname has no DNS record. Its HTTP host, if later configured, redirects to the canonical origin.
Do not publish a second copy under another host.

## Release checks

See `../docs/coordination/website-r291.md` for the feature audit, deployment evidence and remaining release checks.
The current site is a prerelease product and support website. Publication does not establish App Store readiness or app performance acceptance.

## Publish

1. Commit the change on its feature branch.
2. Merge the branch into `main`.
3. Run `bash website/deploy/publish.sh`.
4. Check the public routes and `build.json` source revision.

The script refuses uncommitted source and reuses the existing SSH host configuration.
It preserves the previous site folder and Nginx configuration.
To roll back, point `current` at a retained release folder and reload Nginx after its configuration check passes.
