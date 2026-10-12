from pathlib import Path
import zipfile,json,hashlib,csv,html,collections
from PIL import Image
ROOT=Path(__file__).resolve().parent; D=ROOT/'docs'; P=ROOT/'preview';S=ROOT/'screens'
source=Path('/mnt/data/DealGo_165_Mobile_Phase19_3_Cross_Role_Fixed.zip')
standalone=Path('/mnt/data/DealGo_Phase19_4_25_UI_States_DesignSystem.zip')
combined=Path('/mnt/data/DealGo_165_Mobile_Phase19_4_With_25_UI_States.zip')
metadata=json.loads((D/'states.json').read_text())
assert len(metadata)==25 and len({x['variant_id'] for x in metadata})==25
assert len(list(S.glob('*.png')))==25 and len(list(S.glob('*.html')))==25
for row in metadata:
 image=Image.open(S/f"{row['variant_id']}.png")
 assert image.size==(1000,2036),row
assert '#DG123456' not in (S/'C028__checkout_offline.html').read_text(encoding='utf8')
assert 'không thể được chọn' in (S/'C007__quote_expired.html').read_text(encoding='utf8')
assert 'idempotency key' in (S/'C028__submitting.html').read_text(encoding='utf8')
render=json.loads((D/'render_test_results.json').read_text(encoding='utf8'))
assert len(render)==25 and all(r['layout_pass'] for r in render)
# 25 state variants on 18 existing root routes. No extra route is created.
roots={x['route_id'] for x in metadata}
assert len(roots)==18
all_ids={f'{p}{i:03d}' for p,n in [('S',28),('C',48),('M',44),('D',45)] for i in range(1,n+1)}
assert roots<=all_ids and len(all_ids)==165
with zipfile.ZipFile(source) as z:
 entries={n:z.read(n) for n in z.namelist() if n.endswith('.png') and n.startswith('DealGo_165/screens/')}
 assert len(entries)==165,(len(entries),list(entries)[:5])
 c001=entries['DealGo_165/screens/customer/C001.png']; home=Path('/mnt/data/DealGo Vietnamese App Home Screen.png').read_bytes()
 assert hashlib.sha256(c001).digest()==hashlib.sha256(home).digest()
 assert {Path(n).stem for n in entries}==all_ids

# Static gallery with local thumbnail filters and per-state descriptions.
meta={r['variant_id']:r for r in metadata}
cards='\n'.join(f'''<article class="card" data-role="{html.escape(s['domain'])}" data-query="{html.escape(' '.join([s['variant_id'],s['title'],s['domain'],s['state']]).lower())}"><img src="../screens/{s['variant_id']}.png" loading="lazy" alt="{html.escape(s['title'])}"><div class="details"><b>{html.escape(s['variant_id'])}</b><p>{html.escape(s['title'])} · {html.escape(s['state'])}</p><small>{html.escape(s['trigger'])}</small></div></article>''' for s in metadata)
(P/'gallery.html').write_text('''<!doctype html><html lang="vi"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>DealGo 19.4 — 25 UI states</title><style>*{box-sizing:border-box}body{margin:0;font-family:system-ui,Arial;background:#f5f3fa;color:#171b2c}.top{padding:28px 5%;background:linear-gradient(120deg,#6d28d9,#412385);color:white}h1{margin:0 0 8px}.top p{opacity:.9}.filter{display:flex;gap:8px;flex-wrap:wrap;padding:18px 5%;background:white;position:sticky;top:0;z-index:3;box-shadow:0 2px 20px #32235414}button,input{font:inherit;border:1px solid #e0d7ec;border-radius:9px;padding:9px 12px;background:#fff;cursor:pointer}button.sel{background:#6d28d9;color:white}input{min-width:240px;flex:1}.grid{padding:24px 5%;display:grid;grid-template-columns:repeat(auto-fill,minmax(230px,1fr));gap:18px}.card{min-width:0;background:white;border:1px solid #e6e1ee;border-radius:15px;overflow:hidden;box-shadow:0 6px 22px #2c244514}.card img{width:100%;height:430px;object-fit:contain;background:#f7f6fa}.details{padding:12px}.details b{color:#6d28d9;word-break:break-word}.details p{margin:6px 0}.details small{color:#657084}#n{color:#5820b5;font-weight:700}</style></head><body><header class="top"><h1>DealGo · Phase 19.4</h1><p>25 biến thể trạng thái / 18 route · Không phải route độc lập. C001 không thay đổi.</p></header><div class="filter"><input id="q" type="search" placeholder="Tìm màn hình, trạng thái..." aria-label="Tìm màn hình"><button class="sel" data-filter="all">Tất cả</button>''' + ''.join(f'<button data-filter="{d}">{d}</button>' for d in sorted({x['domain'] for x in metadata})) + '''<span id="n"></span></div><main class="grid">'''+cards+'''</main><script>let current='all';const q=document.querySelector('#q'),cards=[...document.querySelectorAll('.card')];function apply(){let needle=q.value.toLowerCase();let count=0;for(let el of cards){let show=(current==='all'||el.dataset.role===current)&&el.dataset.query.includes(needle);el.style.display=show?'':'none';count+=show;}document.querySelector('#n').textContent=count+' trạng thái';}document.querySelectorAll('button[data-filter]').forEach(b=>b.onclick=()=>{current=b.dataset.filter;document.querySelectorAll('button[data-filter]').forEach(x=>x.classList.toggle('sel',x===b));apply()});q.oninput=apply;apply();</script></body></html>''',encoding='utf8')
(ROOT/'README.md').write_text('''# DealGo Phase 19.4 — 25 UI state variants

- `screens/`: 25 HTML + 25 PNG cho 18 route, không tăng 165 route hiện hành.
- `preview/gallery.html`: xem ảnh offline (mở sau khi giải nén ZIP).
- `preview/DealGo_Phase19_4_25_States.jpg`: bảng tổng hợp.
- `docs/screen_state_matrix.csv`: 25 variant với trigger, hành động, guardrail.
- `docs/screen_state_165_matrix.csv`: đề xuất bao phủ trạng thái cho 165 màn (chỉ 25 đã có ảnh mới).
- `docs/03_DESIGN_SYSTEM_FREEZE_CANDIDATE.md`: token freeze candidate, **chưa được duyệt production**.
- `flutter/dealgo_ui_states.dart`: widget/contract tham khảo, **chưa build bằng Flutter SDK**.

**Lưu ý:** Ảnh là mockup tĩnh, không phải UI production. Bộ 165 màn gốc chỉ là ảnh PNG, vì vậy Ph 19.4 bổ sung state variants chứ không thay hình của 165 route. C001 được bảo tồn nguyên bytes trong bộ ZIP đầy đủ. Dữ liệu giá, đơn hàng và COD là fixture mô phỏng.
''',encoding='utf8')
newfiles=[]
for folder in ['screens','assets','preview','docs','flutter']:
 newfiles += sorted(p for p in (ROOT/folder).rglob('*') if p.is_file())
newfiles += [ROOT/'README.md',ROOT/'build_phase19_4.py',ROOT/'render_check.py',ROOT/'package_and_verify.py']
with zipfile.ZipFile(standalone,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for p in newfiles:z.write(p,arcname=f'DealGo_Phase19_4/{p.relative_to(ROOT)}')
# Repack already verified Phase19.3 bundle; don't overwrite any original route image.
with zipfile.ZipFile(source,'r') as zin, zipfile.ZipFile(combined,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=4) as zout:
 for item in zin.infolist():
  zout.writestr(item,zin.read(item.filename))
 for p in newfiles:
  zout.write(p,arcname=f'DealGo_165/phase19_4/{p.relative_to(ROOT)}')

for fp in [standalone,combined]:
 with zipfile.ZipFile(fp) as z:
  err=z.testzip();assert not err,err
  names=z.namelist();assert len(names)==len(set(names))
  if fp==combined:
   assert sum(n.startswith('DealGo_165/screens/') and n.endswith('.png') for n in names)==165
   assert sum(n.startswith('DealGo_165/phase19_4/screens/') and n.endswith('.png') for n in names)==25
   assert hashlib.sha256(z.read('DealGo_165/screens/customer/C001.png')).digest()==hashlib.sha256(home).digest()
   for name,dat in entries.items():
    assert z.read(name)==dat,'changed screen '+name

report={'original_screen_routes':165,'new_ui_state_variants':25,'routes_with_new_state_mockups':18,'new_routes':0,'render_pass':25,'source_c001_sha256':hashlib.sha256(home).hexdigest(),'combined_bytes':combined.stat().st_size,'standalone_bytes':standalone.stat().st_size,'rechecked_unmodified_main_screens':165,'zip_crc':'PASS'}
(D/'package_validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
# Update validation file after tests; place it into both archives.
with zipfile.ZipFile(standalone,'a',compression=zipfile.ZIP_DEFLATED) as z:z.write(D/'package_validation.json',arcname='DealGo_Phase19_4/docs/package_validation.json')
with zipfile.ZipFile(combined,'a',compression=zipfile.ZIP_DEFLATED) as z:z.write(D/'package_validation.json',arcname='DealGo_165/phase19_4/docs/package_validation.json')
print('PASS',json.dumps(report,ensure_ascii=False,indent=2))
print(standalone);print(combined)
