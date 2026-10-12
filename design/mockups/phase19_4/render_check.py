from pathlib import Path
from playwright.sync_api import sync_playwright
from PIL import Image, ImageDraw, ImageFont
import json,hashlib,collections
ROOT=Path(__file__).resolve().parent; S=ROOT/'screens'; P=ROOT/'preview';D=ROOT/'docs'
P.mkdir(exist_ok=True);D.mkdir(exist_ok=True)
FONT='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
results=[]
with sync_playwright() as pl:
 browser=pl.chromium.launch(headless=True,executable_path='/usr/bin/chromium',args=['--no-sandbox','--disable-gpu','--allow-file-access-from-files'])
 page=browser.new_page(viewport={'width':500,'height':1018},device_scale_factor=2)
 for path in sorted(S.glob('*.html')):
  page.set_content(path.read_text(encoding='utf8'),wait_until='load')
  out=path.with_suffix('.png')
  page.screenshot(path=str(out))
  data=page.evaluate('''()=>{const c=document.querySelector('.content'),f=document.querySelector('.footer'),last=c.lastElementChild,lb=last?.getBoundingClientRect(),fb=f?.getBoundingClientRect();let maxRight=[...document.querySelectorAll('.content *')].reduce((a,e)=>{let x=e.getBoundingClientRect();return Math.max(a,x.right)},0);return {scrollHeight:c.scrollHeight,clientHeight:c.clientHeight,lastBottom:lb?.bottom||0,footerTop:fb?.top||1020,maxRight:maxRight,contentRight:c.getBoundingClientRect().right,missingImages:[...document.images].filter(x=>!x.complete||!x.naturalWidth).length}}''')
  im=Image.open(out)
  data.update({'id':path.stem,'width':im.width,'height':im.height,'sha256':hashlib.sha256(out.read_bytes()).hexdigest()})
  data['layout_pass']=data['scrollHeight'] <= data['clientHeight']+2 and data['lastBottom'] < data['footerTop']-5 and data['maxRight'] < 512 and data['missingImages']==0
  results.append(data)
 browser.close()
(D/'render_test_results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf8')
fails=[r for r in results if not r['layout_pass']]
print('RENDER',len(results),'PASS',len(results)-len(fails),'FAIL',len(fails))
for f in fails:print('FAIL',f['id'], 'height',f['scrollHeight'], f['clientHeight'],'bottom',round(f['lastBottom']),round(f['footerTop']),'maxRight',round(f['maxRight']))

def sheet(records,file,cols=5,thumb_w=350):
 rows=(len(records)+cols-1)//cols
 iw=thumb_w;ih=int(2036*iw/1000)
 border=14;top=46;gap=18
 canv=Image.new('RGB',(border*2+cols*iw+(cols-1)*gap,border*2+rows*(ih+top)+(rows-1)*gap),'#f6f4fb')
 draw=ImageDraw.Draw(canv)
 font=ImageFont.truetype(FONT,15)
 for i,r in enumerate(records):
  img=Image.open(S/(r['id']+'.png')).convert('RGB');img.thumbnail((iw,ih),Image.Resampling.LANCZOS)
  col=i%cols;row=i//cols;x=border+col*(iw+gap);y=border+row*(ih+top+gap)
  draw.rounded_rectangle((x,y,x+iw,y+top+ih),radius=20,fill='#ffffff')
  draw.text((x+12,y+10),r['id'].replace('__',' · '),font=font,fill='#43217a')
  canv.paste(img,(x+int((iw-img.width)/2),y+top))
 canv.save(file,quality=89,optimize=True)
 return file
sheet(results,P/'DealGo_Phase19_4_25_States.jpg',cols=5,thumb_w=340)
meta=json.loads((D/'states.json').read_text())
for domain in sorted({r['domain'] for r in meta}):
 ids={r['variant_id'] for r in meta if r['domain']==domain}
 subset=[r for r in results if r['id'] in ids]
 sheet(subset,P/f'states_{domain}.jpg',cols=min(3,len(subset)),thumb_w=400)
print('Written preview panels for',len({r['domain'] for r in meta}),'domains')
if fails:raise SystemExit(2)
