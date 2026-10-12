from pathlib import Path
from playwright.sync_api import sync_playwright
from PIL import Image,ImageDraw,ImageFont
import json,hashlib
ROOT=Path(__file__).parent;S=ROOT/'screens';D=ROOT/'docs';P=ROOT/'preview'
measure=[]
with sync_playwright() as p:
 b=p.chromium.launch(headless=True,executable_path='/usr/bin/chromium',args=['--no-sandbox','--disable-gpu'])
 page=b.new_page(viewport={'width':500,'height':1018},device_scale_factor=2)
 for path in sorted(S.glob('*.html')):
  page.set_content(path.read_text(encoding='utf8'),wait_until='load')
  page.screenshot(path=str(path.with_suffix('.png')))
  v=page.evaluate('''()=>{let c=document.querySelector('.content'),f=document.querySelector('.footer'),last=c.lastElementChild;let b=c.getBoundingClientRect(),l=last?.getBoundingClientRect();return {scrollHeight:c.scrollHeight,clientHeight:c.clientHeight,lastBottom:l?.bottom,contentBottom:b.bottom,footerTop:f?.getBoundingClientRect().top||null,bodyScroll:document.body.scrollWidth}}''')
  im=Image.open(path.with_suffix('.png'))
  measure.append({'id':path.stem,'width':im.width,'height':im.height,'sha256':hashlib.sha256(path.with_suffix('.png').read_bytes()).hexdigest(),**v})
 b.close()
(D/'layout_measurements.json').write_text(json.dumps(measure,ensure_ascii=False,indent=2),encoding='utf8')
for q in measure:
 overflow=q['scrollHeight']>q['clientHeight']+2 or (q['footerTop'] and q['lastBottom']>q['footerTop']-8)
 print(q['id'], 'FAIL' if overflow else 'PASS',q['scrollHeight'],q['clientHeight'],round(q['lastBottom'] or 0),round(q['footerTop'] or 0))
