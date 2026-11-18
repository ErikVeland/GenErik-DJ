#!/bin/bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"
[ "$(git branch --show-current)" = main ] || { echo 'Switch to main before publication.' >&2; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo 'Commit all changes before publication.' >&2; exit 1; }
REVISION="$(git rev-parse HEAD)"
python3 website/build.py
python3 website/tests/check_site.py
printf '{"source_revision":"%s"}\n' "$REVISION" > website/dist/build.json
ssh -o BatchMode=yes glasscode "test ! -e /var/www/generik/releases/$REVISION"
rsync -az website/dist/ "glasscode:/tmp/generik-$REVISION/"
scp website/deploy/nginx.conf "glasscode:/tmp/generik-$REVISION.conf"
ssh -o BatchMode=yes glasscode bash -s -- "$REVISION" <<'REMOTE'
set -euo pipefail
revision="$1"
sudo -n install -d /var/www/generik/releases
sudo -n cp -a "/tmp/generik-$revision" "/var/www/generik/releases/$revision"
sudo -n chown -R root:root "/var/www/generik/releases/$revision"
sudo -n find "/var/www/generik/releases/$revision" -type d -exec chmod 755 '{}' +
sudo -n find "/var/www/generik/releases/$revision" -type f -exec chmod 644 '{}' +
sudo -n cp -a /etc/nginx/sites-available/generik.conf "/etc/nginx/sites-available/generik.conf.before-$revision"
sudo -n install -m 644 "/tmp/generik-$revision.conf" /etc/nginx/sites-available/generik.conf
if ! sudo -n nginx -t; then
    sudo -n cp -a "/etc/nginx/sites-available/generik.conf.before-$revision" /etc/nginx/sites-available/generik.conf
    exit 1
fi
sudo -n ln -s "/var/www/generik/releases/$revision" "/var/www/generik/current-$revision"
sudo -n mv -Tf "/var/www/generik/current-$revision" /var/www/generik/current
sudo -n systemctl reload nginx
REMOTE
curl --fail --silent --show-error https://dj.generik.au/build.json
