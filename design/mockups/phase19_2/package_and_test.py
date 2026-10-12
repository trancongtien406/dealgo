from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,zipfile,hashlib,collections,re,csv
R=Path(__file__).parent; S=R/'screens';D=R/'docs';P=R/'preview'; SRC=Path('/mnt/data/DealGo_165_ManHinh_Phase19_DaCapNhat.zip')
ids=['M004','M005','M010','M011','M012','M044','D004','D005','D006','D009','D012','D013','D014','D015','D040','D041']
states=['M011_REJECTED','M012_RESUBMITTED','D015_BLOCKED','D015_RESTORED']
assert len(ids)==len(set(ids))==16
for id in ids+states:
 assert (S/(id+'.html')).exists() and (S/(id+'.png')).exists(),id
 img=Image.open(S/(id+'.png'));assert img.size==(1000,2036)
assert 'PENDING_REVIEW' in (S/'D013.html').read_text() and 'PENDING_REVIEW' in (S/'M011.html').read_text()
assert 'KYC-LICENSE-EXPIRED' in (S/'D015.html').read_text() and 'KYB-DOC-EXPIRED' in (S/'M044.html').read_text()
assert 'Giao đồ ăn' in (S/'D015.html').read_text() and 'Chở khách' in (S/'D015.html').read_text()
assert 'RE_SUBMITTED' in (S/'M012.html').read_text() and (S/'D014.html').read_text()
assert 'Honda Vision' in (S/'D041.html').read_text()
assert all('123456789012' not in (S/(id+'.html')).read_text() for id in ids)
metrics=json.loads((D/'layout_measurements.json').read_text());assert len(metrics)==20
for m in metrics:
 assert m['scrollHeight']<=m['clientHeight']+2,(m['id'],'overflow')
 assert m['lastBottom']<=m['footerTop']-8,(m['id'],'footer overlap')
 assert m['bodyScroll']<=500
assert len(list(S.glob('*.png')))==20
# Visual summary of 16 route replacements
TW,TH,COLS=255,544,4
img=Image.new('RGB',(TW*COLS,TH*4),'#f3f1f8');draw=ImageDraw.Draw(img)
for i,sid in enumerate(ids):
 shot=Image.open(S/(sid+'.png')).convert('RGB');shot.thumbnail((TW-10,TH-28));x=(i%COLS)*TW+(TW-shot.width)//2;y=(i//COLS)*TH+26
 img.paste(shot,(x,y));draw.text((x+6,y-21),sid,fill='#5d39bc')
img.save(P/'phase19_2_overview.png',optimize=True)
# Gallery; HTML screen files embed all CSS; images are static and work without internet.
cards=[]
for sid in ids+states:
 kind='Thay thế 165' if sid in ids else 'Trạng thái bổ sung'
 cards.append(f'<article><a href="../screens/{sid}.png"><img loading="lazy" src="../screens/{sid}.png" alt="Màn hình {sid}"><strong>{sid}</strong></a><p>{kind}</p><a class="sub" href="../screens/{sid}.html">Xem HTML nguồn</a></article>')
(P/'gallery.html').write_text('''<!doctype html><html lang="vi"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>DealGo — Phase 19.2</title><style>body{font:15px system-ui;background:#f4f1f9;color:#1e2030;margin:0}header{max-width:1060px;margin:auto;padding:25px}h1{margin:0}p{color:#626577}section{max-width:1200px;margin:auto;display:grid;grid-template-columns:repeat(auto-fit,minmax(210px,1fr));gap:20px;padding:12px 25px 50px}article{background:white;border-radius:20px;padding:10px;text-align:center;box-shadow:0 6px 20px #22133312}img{width:100%;border-radius:12px}strong{display:block;padding-top:10px;color:#5f27c1;font-size:18px}a{text-decoration:none}.sub{font-size:12px;color:#7351a7}</style><header><h1>DealGo · Phase 19.2</h1><p>16 màn hình KYC/KYB đã cập nhật + 4 biến thể trạng thái. Mọi dữ liệu và giấy tờ minh họa đã được làm mờ; đây không phải chức năng KYC thật.</p></header><section>'''+''.join(cards)+'''</section></html>''',encoding='utf8')
manifest=[]
with zipfile.ZipFile(SRC,'r') as zin:
 names=zin.namelist()
 originals={Path(n).stem:n for n in names if n.startswith('DealGo_165/screens/') and n.endswith('.png')}
 assert len(originals)==165
 for sid in ids:
  assert sid in originals,sid
  before=hashlib.sha256(zin.read(originals[sid])).hexdigest()
  after=hashlib.sha256((S/(sid+'.png')).read_bytes()).hexdigest()
  assert before!=after,('unchanged!',sid)
  manifest.append(dict(screen_id=sid,role='merchant' if sid[0]=='M' else 'driver',before_sha256=before,after_sha256=after,zip_path=originals[sid],change_type='REPLACED'))
 for sid in states:manifest.append(dict(screen_id=sid,role='merchant' if sid[0]=='M' else 'driver',before_sha256='',after_sha256=hashlib.sha256((S/(sid+'.png')).read_bytes()).hexdigest(),zip_path='DealGo_165/phase19_2/states/'+sid+'.png',change_type='ADDITIONAL_STATE_NOT_ROUTE'))
(D/'patch_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
with (D/'patch_manifest.csv').open('w',newline='',encoding='utf-8-sig') as f:
 w=csv.DictWriter(f,fieldnames=list(manifest[0]));w.writeheader();w.writerows(manifest)
# Deliverable A: light delta
small=Path('/mnt/data/DealGo_Phase19_2_KYC_KYB_20_Mockup.zip')
with zipfile.ZipFile(small,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for folder in (S,D,P):
  for file in sorted(folder.iterdir()):
   if file.is_file():z.write(file,'DealGo_Phase19_2/'+str(file.relative_to(R)))
 for f in ['build_phase19_2.py','render_validate.py','package_and_test.py']:
  z.write(R/f,'DealGo_Phase19_2/'+f)
# Deliverable B: merged full 165 snapshots from version 19.1, replacing exactly 16.
full=Path('/mnt/data/DealGo_165_Mobile_Phase19_2_KYC_KYB_Fixed.zip')
replaced=[]
with zipfile.ZipFile(SRC,'r') as zin,zipfile.ZipFile(full,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=4) as zout:
 for n in zin.namelist():
  path=Path(n); sid=path.stem
  if n.startswith('DealGo_165/screens/') and path.suffix=='.png' and sid in ids:
   data=(S/(sid+'.png')).read_bytes();replaced.append(sid)
  else:data=zin.read(n)
  zout.writestr(n,data)
 for file in sorted([*S.glob('*.html'),*D.glob('*'),*P.glob('*')]):
  if file.is_file():zout.write(file,'DealGo_165/phase19_2/'+str(file.relative_to(R)))
 for sid in states:zout.write(S/(sid+'.png'),'DealGo_165/phase19_2/states/'+sid+'.png')
 for f in ['build_phase19_2.py','render_validate.py','package_and_test.py']:
  zout.write(R/f,'DealGo_165/phase19_2/'+f)
assert set(replaced)==set(ids)
with zipfile.ZipFile(SRC) as src,zipfile.ZipFile(full) as new:
 srcScreens={n:src.read(n) for n in src.namelist() if n.startswith('DealGo_165/screens/') and n.endswith('.png')}
 newScreens={n:new.read(n) for n in new.namelist() if n.startswith('DealGo_165/screens/') and n.endswith('.png')}
 assert len(srcScreens)==len(newScreens)==165
 changed={Path(k).stem for k in srcScreens if srcScreens[k]!=newScreens[k]}
 assert changed==set(ids),changed
 assert srcScreens['DealGo_165/screens/customer/C001.png']==newScreens['DealGo_165/screens/customer/C001.png']
 for sid in ids:
  n=next(k for k in newScreens if Path(k).stem==sid)
  assert hashlib.sha256(newScreens[n]).hexdigest()==hashlib.sha256((S/(sid+'.png')).read_bytes()).hexdigest()
print('PASS: 16 replacements, 4 state variants, exact 165 route screenshots, unchanged C001, layout checks and policy checks.')
print('FILES:',small,round(small.stat().st_size/1024/1024,2),'MB;',full,round(full.stat().st_size/1024/1024,2),'MB')
