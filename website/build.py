#!/usr/bin/env python3
"""Build the complete static site without network access or runtime dependencies."""
import hashlib
import html
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent
CONFIG = json.loads((ROOT / 'site.json').read_text())
OUT = ROOT / 'dist'
PLATFORMS = ', '.join(CONFIG['platforms'][:-1]) + ' and ' + CONFIG['platforms'][-1]
PAGES = [
    ('/', 'home', 'GenErik DJ — Native DJ software', f'DJ software for {PLATFORMS}. Choose the controls you need, hide the rest and mix by touch.'),
    ('/manual', 'manual', 'Manual', 'Task-based help for the GenErik DJ development build: library, decks, grids, Sync, mixing and recording.'),
    ('/support', 'support', 'Support', 'Get help with GenErik DJ. Troubleshooting, bug reports, feature requests and contact details for Erik Veland.'),
    ('/privacy', 'privacy', 'Privacy', 'How the GenErik DJ development app and website handle music, preparation, iCloud, diagnostics and support information.'),
    ('/privacy/choices', 'choices', 'Privacy choices', 'Manage GenErik DJ permissions, local data, iCloud preparation and privacy requests.'),
    ('/accessibility', 'accessibility', 'Accessibility', 'Accessibility information for the GenErik DJ website and the app’s current verification limits.'),
    ('/terms', 'terms', 'Terms of use', 'Application licensing, Apple’s Standard EULA and contact details for GenErik DJ.'),
    ('/release-notes', 'releases', 'Release notes', 'GenErik DJ public release history and current development status.'),
    ('/legal', 'legal', 'Legal', 'GenErik DJ privacy, terms, accessibility, licences and developer contact information.'),
    ('/credits', 'credits', 'Credits & licences', 'Open-source audio, analysis and typography acknowledgements for GenErik DJ.'),
    ('/404', '404', 'Page not found', 'The requested GenErik DJ page does not exist.'),
    ('/503', '503', 'Temporarily unavailable', 'The GenErik DJ website is temporarily unavailable.')
]


def build():
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir()
    shutil.copytree(ROOT / 'assets', OUT / 'assets')
    css = '/assets/site.' + hashlib.sha256((OUT / 'assets/site.css').read_bytes()).hexdigest()[:12] + '.css'
    (OUT / 'assets/site.css').rename(OUT / css.lstrip('/'))
    origin = CONFIG['origin']
    navigation = [('/', 'Product'), ('/manual', 'Manual'), ('/support', 'Support')]
    footer = navigation + [('/privacy', 'Privacy'), ('/privacy/choices', 'Privacy choices'), ('/accessibility', 'Accessibility'), ('/terms', 'Terms'), ('/release-notes', 'Release notes'), ('/legal', 'Legal'), ('/credits', 'Credits')]
    def links(items, route):
        return ''.join(f'<a href="{url}"' + (' aria-current="page"' if url == route else '') + f'>{label}</a>' for url, label in items)
    for route, source, title, description in PAGES:
        is_home = route == '/'
        title_full = title if is_home else title + ' — GenErik DJ'
        canonical = origin + (route if not is_home else '/')
        schema = [{"@context": "https://schema.org", "@type": "WebSite", "@id": origin + '/#website', "name": CONFIG['name'], "url": origin + '/', "inLanguage": "en-AU", "creator": {"@type": "Person", "name": CONFIG['developer'], "url": origin + '/support'}}]
        if is_home:
            schema.append({"@context":"https://schema.org", "@type":"SoftwareApplication", "name":"GenErik DJ", "url":canonical, "applicationCategory":"MultimediaApplication", "operatingSystem":CONFIG["operating_systems"], "availableOnDevice":CONFIG["platforms"], "description":description, "creativeWorkStatus":"In development", "author":{"@type":"Person","name":CONFIG['developer']}, "image":origin+'/assets/social.jpg'})
        elif source not in ('404', '503'):
            schema.append({"@context":"https://schema.org", "@type":"BreadcrumbList", "itemListElement":[{"@type":"ListItem","position":1,"name":"GenErik DJ","item":origin+'/'},{"@type":"ListItem","position":2,"name":title,"item":canonical}]})
        body = (ROOT / 'content' / (source + '.html')).read_text().replace('{{platforms}}', html.escape(PLATFORMS))
        if not is_home:
            body = f'<div class="document-heading"><h1>{html.escape(title)}</h1><a href="/">GenErik DJ</a></div><div class="document-body">{body}</div>'
        robots = '<meta name="robots" content="noindex,follow">' if source in ('404', '503') else ''
        page = f'''<!doctype html>
<html lang="en-AU"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title_full)}</title><meta name="description" content="{html.escape(description, quote=True)}">
<link rel="canonical" href="{canonical}">{robots}
<meta property="og:type" content="website"><meta property="og:site_name" content="GenErik DJ"><meta property="og:locale" content="en_AU">
<meta property="og:title" content="{html.escape(title_full, quote=True)}"><meta property="og:description" content="{html.escape(description, quote=True)}"><meta property="og:url" content="{canonical}">
<meta property="og:image" content="{origin}/assets/social.jpg"><meta property="og:image:width" content="1200"><meta property="og:image:height" content="630"><meta property="og:image:alt" content="GenErik DJ development interface: waveform detail beneath the product name.">
<meta name="twitter:card" content="summary_large_image"><meta name="theme-color" content="#0b0d0e">
<link rel="icon" href="/assets/favicon.png" type="image/png"><link rel="preload" href="/assets/archivo-latin.woff2" as="font" type="font/woff2" crossorigin><link rel="stylesheet" href="{css}">
<script type="application/ld+json">{json.dumps(schema,ensure_ascii=False).replace('<', chr(92)+'u003c')}</script>
</head><body><a class="skip" href="#main">Skip to content</a>
<header class="site-header"><div class="header-inner"><a class="brand" href="/" aria-label="GenErik DJ home"><img src="/assets/mark.png" alt="" width="37" height="37">GenErik DJ</a><nav class="primary-nav" aria-label="Primary">{links(navigation, route)}</nav></div></header>
<main id="main" class="page {'home' if is_home else 'document'}">{body}</main>
<footer class="site-footer"><div class="footer-inner"><nav class="footer-nav" aria-label="Footer">{links(footer, route)}</nav><div class="footer-meta"><p>© 2026 Erik Veland</p><p>Independent software. In development.</p><p><a href="mailto:{CONFIG['contact']}">{CONFIG['contact']}</a></p></div></div></footer></body></html>'''
        target = OUT / ('index.html' if is_home else route.lstrip('/') + '/index.html')
        target.parent.mkdir(parents=True,exist_ok=True)
        target.write_text(page)
    public = [p[0] for p in PAGES if p[1] not in ('404', '503')]
    (OUT / 'sitemap.xml').write_text('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">' + ''.join(f'<url><loc>{origin}{p}</loc></url>' for p in public) + '</urlset>\n')
    (OUT / 'robots.txt').write_text(f'User-agent: *\nAllow: /\nSitemap: {origin}/sitemap.xml\n')
    print(f'Built {len(PAGES)} routes in {OUT}')

if __name__ == '__main__':
    build()
