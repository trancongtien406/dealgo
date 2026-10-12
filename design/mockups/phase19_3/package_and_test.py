from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json,zipfile,hashlib,re,csv
from collections import Counter
R=Path(__file__).parent; S=R/'screens'; P=R/'preview'; D=R/'docs'; A=R/'assets'
source=Path('/mnt/data/DealGo_165_Mobile_Phase19_2_KYC_KYB_Fixed.zip')
ids=json.loads((D/'patch_ids.json').read_text())
f=json.loads((D/'golden_order.json').read_text())
assert len(ids)==26==len(set(ids))
assert len(list(S.glob('*.html')))==len(list(S.glob('*.png')))==26
assert all((S/(id+'.html')).exists() and (S/(id+'.png')).exists() for id in ids)
assert all(Image.open(S/(id+'.png')).size==(1000,2036) for id in ids)
assert sum(i['unitPrice']*i['qty'] for i in f['items'])==125000
assert f['subtotal']+f['deliveryFee']-f['discount']==f['payable']==150000
assert f['merchantReceivable']+f['driverEarning']+f['platformDeliveryFee']==f['payable']
assert f['cashToReconcile']==f['payable']-f['driverEarning']
assert f['quoteVersion']==1 and f['orderVersion']==1
html={s:(S/(s+'.html')).read_text() for s in ids}
for id,body in html.items():
 assert '#DG123456' in body or 'DG123456' in body or id in ['C027','C028','C030','C031'],id
 assert '150.000đ' in body or id in ['D026','D027','M017','D018','D020','C035','D031'],id
 assert '6d28d9' in body and '16a34a' in body,id
assert '150.000đ' in html['C028'] and '125.000đ' in html['C028']
for sid in ['C033','D030','D036','M035']:
 assert '150.000đ' in html[sid],sid
for sid in ['M016','M035','D036','D030']:
 assert '125.000đ' in html[sid],sid
for sid in ['D019','D030','D036']:
 assert '20.000đ' in html[sid],sid
assert '130.000đ' in html['D036'] and '130.000đ' in html['D030']
assert 'Chưa thu tiền' in html['C028'] and 'Chưa thu tiền' in html['C032'] or 'chưa thu' in html['C032'].lower()
assert 'Chưa đối soát' not in html['D036'] or 'PENDING_RECONCILIATION' in html['D036']
for sid in ['C034','M018']:
 assert 'Nước chanh' in html[sid] and '25.000đ' in html[sid],sid
assert 'DELIVERY_FAILED' in html['D031'] and 'COD đã thu' in html['D031']
assert '2891' in html['M019'] and '2 8 9 1' in html['D028']
metrics=json.loads((D/'layout_measurements.json').read_text()); assert len(metrics)==26
for mt in metrics:
 assert mt['scrollHeight']<=mt['clientHeight']+2,(mt['id'],'scroll')
 assert mt['lastBottom'] <= mt['footerTop']-8,(mt['id'],'footer')
 assert mt['bodyScroll']<=500,(mt['id'],'width')

# summary images grouped by role, desktop zoom in gallery
font='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'; font=ImageFont.truetype(font,21) if Path(font).exists() else ImageFont.load_default()
def sheet(ids,cols=5,name='overview'):
    tw,th=270,578; rows=(len(ids)+cols-1)//cols
    img=Image.new('RGB',(tw*cols,th*rows),'#f2f0f8');d=ImageDraw.Draw(img)
    for i,sid in enumerate(ids):
        a=Image.open(S/(sid+'.png')).convert('RGB');a.thumbnail((tw-15,th-35))
        x=(i%cols)*tw+(tw-a.width)//2;y=(i//cols)*th+32
        img.paste(a,(x,y));d.text((x+7,y-29),sid,fill='#5b2ca8',font=font)
    img.save(P/(name+'.jpg'),quality=90,optimize=True)
sheet(ids,5,'phase19_3_all_26_screens')
for group,title in [('C','phase19_3_customer_10'),('M','phase19_3_shop_6'),('D','phase19_3_driver_10')]:sheet([id for id in ids if id[0]==group],5,title)
# plain offline HTML gallery
cards=[]
for id in ids:
 label={'C':'Khách hàng','D':'Tài xế','M':'Shop'}[id[0]]
 cards.append(f'<article><a href="../screens/{id}.png"><img src="../screens/{id}.png" loading="lazy" alt="Màn hình {id}"/><strong>{id}</strong></a><small>{label}</small><a class="other" href="../screens/{id}.html">Xem bản HTML</a></article>')
(P/'gallery.html').write_text('<!DOCTYPE html><html lang="vi"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>DealGo Phase 19.3</title><style>body{font-family:system-ui;background:#f4f1fa;color:#191521;margin:0;padding:30px}h1,p{max-width:1150px;margin:10px auto 20px}p{color:#666}main{max-width:1320px;margin:20px auto;display:grid;grid-template-columns:repeat(auto-fill,minmax(225px,1fr));gap:20px}article{background:white;border-radius:18px;padding:10px;box-shadow:0 5px 20px #32215d10;text-align:center}img{width:100%;border-radius:12px}strong{display:block;font-size:20px;color:#6d28d9;margin-top:8px}small{display:block;color:#666}.other{display:block;margin:12px;color:#6d28d9}a{text-decoration:none}</style></head><body><h1>DealGo · Phase 19.3: Cross-role order consistency</h1><p>26 màn được sửa. Số tiền, trạng thái, tài xế, Shop, mã đơn và mã bàn giao thống nhất theo fixture; trạng thái ngoại lệ là nhánh lựa chọn, không xảy ra đồng thời với luồng chính.</p><main>'+''.join(cards)+'</main></body></html>',encoding='utf-8')
manifest=[]
with zipfile.ZipFile(source) as zin:
    originals={Path(n).stem:n for n in zin.namelist() if n.startswith('DealGo_165/screens/') and n.endswith('.png')}
    assert len(originals)==165,len(originals)
    for sid in ids:
        assert sid in originals
        src=zin.read(originals[sid]); dest=(S/(sid+'.png')).read_bytes()
        assert src!=dest
        manifest.append({'id':sid,'role':{'C':'customer','M':'shop','D':'driver'}[sid[0]],'archive_path':originals[sid], 'source_sha256':hashlib.sha256(src).hexdigest(),'new_sha256':hashlib.sha256(dest).hexdigest()})
(D/'patch_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
with (D/'patch_manifest.csv').open('w',newline='',encoding='utf-8-sig') as out:
    w=csv.DictWriter(out,fieldnames=list(manifest[0]));w.writeheader();w.writerows(manifest)

report={'screens_replaced':len(ids),'unchanged_routes':165-len(ids),'total_routes':165,'golden_cart_subtotal':f['subtotal'],'golden_delivery_fee':f['deliveryFee'],'golden_cod':f['payable'],'driver_earnings':f['driverEarning'],'cod_to_reconcile':f['cashToReconcile'],'merchant_receivable':f['merchantReceivable'],'layout_passed':len(metrics),'source_archive':source.name,'c001_unchanged':True,'replaced_ids':ids,'status':'PASS'}
(D/'test_results.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')

small=Path('/mnt/data/DealGo_Phase19_3_26_Screens_Cross_Role_Fixed.zip')
with zipfile.ZipFile(small,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for dir in (S,D,P,A):
  for path in sorted(dir.iterdir()):
   if path.is_file():z.write(path,'DealGo_Phase19_3/'+str(path.relative_to(R)))
 for file in ('build_phase19_3.py','render_validate.py','package_and_test.py'):
  z.write(R/file,'DealGo_Phase19_3/'+file)
full=Path('/mnt/data/DealGo_165_Mobile_Phase19_3_Cross_Role_Fixed.zip')
with zipfile.ZipFile(source) as zin,zipfile.ZipFile(full,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=4) as zout:
 for name in zin.namelist():
  sid=Path(name).stem
  data=(S/(sid+'.png')).read_bytes() if name.startswith('DealGo_165/screens/') and name.endswith('.png') and sid in ids else zin.read(name)
  zout.writestr(name,data)
 for directory in (S,D,P,A):
  for path in sorted(directory.iterdir()):
   if path.is_file():zout.write(path,'DealGo_165/phase19_3/'+str(path.relative_to(R)))
 for file in ('build_phase19_3.py','render_validate.py','package_and_test.py'):
  zout.write(R/file,'DealGo_165/phase19_3/'+file)
with zipfile.ZipFile(source) as a,zipfile.ZipFile(full) as b:
 original={n:a.read(n) for n in a.namelist() if n.startswith('DealGo_165/screens/') and n.endswith('.png')}
 newer={n:b.read(n) for n in b.namelist() if n.startswith('DealGo_165/screens/') and n.endswith('.png')}
 assert len(original)==len(newer)==165
 changed={Path(n).stem for n in original if original[n]!=newer[n]}
 assert changed==set(ids),(len(changed),changed^set(ids))
 assert original['DealGo_165/screens/customer/C001.png']==newer['DealGo_165/screens/customer/C001.png']
 for sid in ids:
  name=next(n for n in newer if Path(n).stem==sid)
  assert hashlib.sha256(newer[name]).hexdigest()==hashlib.sha256((S/(sid+'.png')).read_bytes()).hexdigest()
print('SUCCESS',json.dumps({'replace':26,'total':165,'unchanged':139,'c001':'preserved','light_MiB':round(small.stat().st_size/1048576,2),'full_MiB':round(full.stat().st_size/1048576,2)},ensure_ascii=False))
