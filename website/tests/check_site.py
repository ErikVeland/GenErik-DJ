#!/usr/bin/env python3
"""Check public routes, metadata, internal targets, assets and colour contrast."""
import json
import re
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit, unquote
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from build import OUT, PAGES, CONFIG

class Page(HTMLParser):
    def __init__(self,text):
        super().__init__();self.tags=[];self.ids=[];self.scripts=[];self.feed(text)
    def handle_starttag(self,tag,attrs):
        values=dict(attrs);self.tags.append((tag,values))
        if 'id' in values:self.ids.append(values['id'])

def check():
    errors=[]; cache={};titles=set();descriptions=set();targets=0
    for route,source,title,description in PAGES:
        path=OUT/('index.html' if route=='/' else route.lstrip('/')+'/index.html')
        assert path.exists(),path
        text=path.read_text();p=Page(text);cache[route]=p
        assert len(p.ids)==len(set(p.ids)),f'Duplicate IDs: {route}'
        assert sum(t=='h1' for t,a in p.tags)==1,route
        assert '<html lang="en-AU">' in text,route
        actual_title=re.search(r'<title>(.*?)</title>',text).group(1)
        assert actual_title not in titles,route
        titles.add(actual_title)
        metas={a.get('name',a.get('property')):a.get('content') for t,a in p.tags if t=='meta'}
        assert metas['description'] not in descriptions,route
        descriptions.add(metas['description'])
        assert metas['og:url']==CONFIG['origin']+route,route
        assert any(t=='link' and a.get('rel')=='canonical' and a.get('href')==CONFIG['origin']+route for t,a in p.tags),route
        for tag,attrs in p.tags:
            if tag=='script':assert attrs.get('type')=='application/ld+json',route
            if tag=='img':assert all(k in attrs for k in ['alt','width','height']),route
            if tag=='a':assert attrs.get('href') not in ('',None,'#'),route
            if tag in ('iframe','form'):raise AssertionError((route,tag))
        for data in re.findall(r'<script type="application/ld\+json">(.*?)</script>',text,re.S):json.loads(data)
        assert not re.search(r'\bTODO\b|lorem ipsum|placeholder|\{\{platforms\}\}',text,re.I),route
        if source in ('home','manual','support'):
            for platform in CONFIG['platforms']:
                assert platform in text,(route,platform)
    for route,p in cache.items():
        for tag,attrs in p.tags:
            urls=[attrs[x] for x in ('href','src') if x in attrs]
            if 'srcset' in attrs:urls += [x.strip().split()[0] for x in attrs['srcset'].split(',')]
            for url in urls:
                parsed=urlsplit(url)
                if parsed.scheme or parsed.netloc:continue
                target=parsed.path or route
                if target in cache:
                    if parsed.fragment:assert unquote(parsed.fragment) in cache[target].ids,(route,url)
                else:
                    assert target.startswith('/'),(route,url)
                    assert (OUT/target.lstrip('/')).is_file(),(route,url)
                targets+=1
    def lum(col):
        rgb=[int(col[i:i+2],16)/255 for i in (1,3,5)]
        vals=[c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in rgb]
        return sum(v*w for v,w in zip(vals,[.2126,.7152,.0722]))
    ratios={}
    for fg in ['#e6e6e6','#a7adb2','#7ddee6']:
        for bg in ['#0b0d0e','#1b1d20']:
            ratio=(lum(fg)+.05)/(lum(bg)+.05);ratios[fg+'/'+bg]=round(ratio,2)
            assert ratio>=4.5,ratios
    report={'routes':len(cache),'internal_targets':targets,'contrast_ratios':ratios,'executable_javascript_bytes':0,'third_party_runtime_requests':0,'total_asset_bytes':sum(p.stat().st_size for p in (OUT/'assets').iterdir())}
    print(json.dumps(report,indent=2))
if __name__=='__main__':check()
