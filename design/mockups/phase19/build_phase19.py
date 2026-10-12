from pathlib import Path
import json, shutil, os, csv, zipfile
ROOT=Path(__file__).parent
S=ROOT/'screens'; A=ROOT/'assets'; D=ROOT/'docs'
for d in [S,A,D]:d.mkdir(exist_ok=True)
fx={
 'ride_car': {'rideId':'RIDE_CAR_001','service':'CAR_4','pickup':'123 Nguyễn Văn Linh, Hải Châu, Đà Nẵng','destination':'Sân bay Đà Nẵng','driverId':'DRV_CAR_HUNG','driver':'Nguyễn Văn Hùng','vehicle':'Toyota Vios · Xe 4 chỗ','plate':'43A-567.89','quoteId':'Q-CAR-0007','fareVersion':1,'fareOpening':25000,'fareDistance':17000,'fees':0,'discount':0,'acceptedQuoteAmount':42000,'payable':42000,'paymentMethod':'Tiền mặt','paymentStatus':'UNPAID','quoteState':'ACCEPTED'},
 'ride_bike': {'rideId':'RIDE_BIKE_001','service':'BIKE','driver':'Trần Minh Anh','vehicle':'Honda Vision 2023','plate':'43H1-123.45','acceptedQuoteAmount':45000},
 'food': {'orderId':'DG123456','version':1,'shop':'Bún Bò Huế O Cô','customer':'Mai Anh','items':[{'name':'Bún bò đặc biệt','qty':1,'price':60000},{'name':'Bún bò thường','qty':1,'price':40000},{'name':'Trà tắc','qty':1,'price':25000}], 'subtotal':125000,'deliveryFee':25000,'discount':0,'payable':150000,'paymentMethod':'COD','paymentState':'COD_NOT_YET_COLLECTED','deliveryState':'AWAITING_MERCHANT','driver':'Trần Minh Anh','driverEarnings':20000,'platformDeliveryFee':5000,'driverCashToReconcile':130000,'merchantGross':125000,'merchantNet':125000}
}
(D/'golden_fixtures.json').write_text(json.dumps(fx,ensure_ascii=False,indent=2),encoding='utf8')
def money(n):return f'{n:,}'.replace(',','.')+'đ'
R=fx['ride_car']; F=fx['food']

css='''
:root{--purple:#6d28d9;--purpleDark:#5820b5;--purple100:#f3edff;--green:#16a34a;--green100:#e7f8ee;--ink:#171b2c;--muted:#71778c;--border:#e9e5f0;--surface:#fbfafd}
*{box-sizing:border-box}html,body{margin:0;padding:0;background:#edeaf4;font-family:Inter,"Noto Sans",Arial,sans-serif;color:var(--ink);-webkit-font-smoothing:antialiased}
.stage{width:500px;height:1018px;padding:20px 24px;background:radial-gradient(ellipse at 0 0,#e9deff,transparent 42%),radial-gradient(ellipse at 100% 100%,#e4f8eb,transparent 46%),#f5f4f9}
.phone{position:relative;width:452px;height:978px;overflow:hidden;border:8px solid #111216;border-radius:57px;background:var(--surface);box-shadow:0 14px 32px #23213432}
.phone:before{content:"";position:absolute;top:5px;left:147px;width:140px;height:27px;border-radius:0 0 17px 17px;background:#111216;z-index:60}
.status{height:43px;background:#fff;padding:15px 26px 0 35px;font-size:14px;font-weight:800;display:flex;justify-content:space-between;position:relative;z-index:4}
.status .bars{font-size:15px;letter-spacing:1px}.header{height:68px;padding:9px 22px;background:#fff;display:flex;align-items:center;gap:12px;border-bottom:1px solid #f4f1f7;position:relative;z-index:3}
.back{border-radius:50%;width:37px;height:37px;display:grid;place-items:center;background:white;border:1px solid #eeeaf5;font-size:22px;font-weight:500;color:#241b3c}
.htext{min-width:0;flex:1}.htext h1{font-size:19px;font-weight:830;line-height:1.2;letter-spacing:-.5px;margin:0}.htext small{font-size:10.5px;color:var(--muted)}
.brand{font-size:24px;font-weight:950;letter-spacing:-1.2px}.brand .p{color:#702bcf}.brand .g{color:#14a13c}
.topaction{font-size:11px;font-weight:750;color:var(--purple);background:#f4edff;border-radius:30px;padding:10px 12px}
.viewport{position:absolute;top:111px;bottom:17px;left:0;right:0;overflow:hidden;background:linear-gradient(180deg,#fbfaff 0%,#fff 58%,#fcfdfd 100%)}
.content{height:100%;padding:15px 18px 90px;overflow:hidden}.content.withnav{padding-bottom:105px}
.card{border:1px solid var(--border);border-radius:19px;padding:14px;background:white;box-shadow:0 4px 18px #3a28550b;margin-bottom:12px}.card.purple{background:linear-gradient(105deg,#f5efff,#fff);border-color:#e7dafa}
.card.green{background:var(--green100);border-color:#d3ebda}.card.warning{background:#fff6e7;border-color:#f4e2bd}.card.red{background:#fff1f3;border-color:#fae0e4}
.title{font-weight:860;font-size:17px;letter-spacing:-.35px}.subtitle{font-size:12px;color:var(--muted);line-height:1.5}.label{font-size:11px;color:var(--muted);line-height:1.4}.small{font-size:12px}.tiny{font-size:10.5px}.bold{font-weight:800}.muted{color:var(--muted)}.purpletext{color:var(--purple)}.greentext{color:var(--green)}.redtext{color:#d62d50}
.row{display:flex;align-items:center;gap:10px}.row.between{justify-content:space-between}.row.start{align-items:flex-start}.col{display:flex;flex-direction:column;gap:5px}.flex1{flex:1;min-width:0}.mt8{margin-top:8px}.mt12{margin-top:12px}.mb8{margin-bottom:8px}.line{height:1px;background:#f0edf4;margin:12px 0}.gap8{gap:8px}
.logoicon{width:41px;height:41px;flex:none;border-radius:14px;display:grid;place-items:center;background:#efe8fb;font-size:21px;color:var(--purple)}.logoicon.green{color:var(--green);background:#e8f7ed}.logoicon.orange{color:#d76d1d;background:#fff3e7}
.pill{display:inline-flex;align-items:center;gap:5px;font-size:10.5px;border-radius:100px;padding:6px 10px;font-weight:750;background:#f0ecf8;color:#6432b4}.pill.green{background:#e4f8ea;color:#168840}.pill.red{background:#ffebed;color:#c73449}.pill.orange{background:#fff2df;color:#a65e18}.pill.gray{background:#f2f3f6;color:#656a7a}
.money{font-size:27px;color:var(--purple);font-weight:900;letter-spacing:-.8px}.money.med{font-size:22px}.money.green{color:#169243}
.input{background:#f9f8fc;border:1px solid #e6e2ed;border-radius:13px;padding:13px 14px;font-size:13px;line-height:1.35}
.divrow{display:flex;align-items:center;gap:10px;padding:12px 0;border-bottom:1px solid #f1eef5}.divrow:last-child{border-bottom:0}
.trip{padding-left:27px;position:relative}.trip:before{content:"";position:absolute;left:7px;top:15px;bottom:16px;border-left:2px dashed #d9d0e7}
.stop{position:relative;padding:4px 0 11px}.stop:last-child{padding-bottom:2px}.stop:before{content:"";position:absolute;top:10px;left:-27px;width:13px;height:13px;border-radius:50%;background:#21bb60;box-shadow:0 0 0 4px #e3f8e9}.stop:last-child:before{background:#f05a69;box-shadow:0 0 0 4px #ffebed}
.rideimg{width:110px;height:66px;border-radius:15px;background:linear-gradient(125deg,#f3eaff,#e9f9ee);display:grid;place-items:center;font-size:38px;flex:none}.map{height:260px;border:1px solid #e6e9ef;border-radius:18px;background:#eef4f8 url("../assets/danang_route_map.png") center/cover no-repeat;position:relative;overflow:hidden;margin-bottom:12px}
.map.smallmap{height:168px}.map .floating{position:absolute;top:12px;left:12px;background:white;border-radius:14px;padding:8px 11px;font-size:12px;font-weight:800;box-shadow:0 3px 13px #33333325}.map .mapbottom{position:absolute;bottom:12px;right:12px;background:#6d28d9;color:white;border-radius:14px;padding:8px 11px;font-size:11px;font-weight:800}
.item{display:flex;gap:10px;align-items:center;padding:10px 0;border-bottom:1px solid #f2eff7}.item:last-child{border-bottom:0}
.avatar{width:49px;height:49px;background:linear-gradient(140deg,#d9f8e2,#ddd7f9);border:3px solid white;box-shadow:0 0 0 1px #e7e2f0;border-radius:50%;display:grid;place-items:center;font-size:18px;font-weight:900;color:#4f2db2;flex:none}.avatar.sm{width:34px;height:34px;font-size:13px}
.btn{min-height:47px;border-radius:15px;background:linear-gradient(105deg,#6022ce,#7e38d7);color:#fff;font-size:14px;font-weight:800;display:flex;align-items:center;justify-content:center;gap:8px;padding:9px 12px;border:0}.btn.outline{background:white;border:1px solid #a875e4;color:#682acb;box-shadow:none}.btn.green{background:linear-gradient(110deg,#159849,#20ba64)}
.footer{position:absolute;z-index:6;bottom:12px;left:18px;right:18px;background:linear-gradient(180deg,#fffffff2,#fff 22%);padding-top:13px}
.footer .btn{min-height:49px}.nav{position:absolute;z-index:5;bottom:0;left:0;right:0;height:72px;display:flex;background:#fff;border-top:1px solid #f1eef5;padding:8px 9px 13px}.nav .tab{flex:1;text-align:center;font-size:10px;color:#888697}.nav .tab span{display:block;font-size:21px;margin-bottom:4px}.nav .tab.sel{color:var(--purple);font-weight:850}
.homepill{position:absolute;z-index:70;width:106px;height:5px;background:#17151c;border-radius:10px;bottom:9px;left:calc(50% - 53px)}
.grid2{display:grid;grid-template-columns:1fr 1fr;gap:9px}.grid3{display:grid;grid-template-columns:repeat(3,1fr);gap:9px}.metric{border:1px solid #eae5f0;background:white;border-radius:15px;padding:12px}.metric strong{font-size:18px;display:block;margin:5px 0}.metric .label{font-size:10px}
.progress{height:8px;background:#eae6f2;border-radius:10px;overflow:hidden}.progress>div{height:100%;background:linear-gradient(90deg,#16ad54,#71d39a)}
.foodimg{width:72px;height:68px;object-fit:cover;border-radius:13px;flex:none}.notice{background:#edf9f0;color:#1b7d42;border-radius:12px;padding:11px 12px;font-size:11px;line-height:1.5}.notice.amber{background:#fff5e8;color:#a05e20}.miniStep{display:flex;justify-content:space-between;margin:10px 0 15px}.miniStep span{font-size:10px;color:#8f8c9a;flex:1;text-align:center}.miniStep span.done{color:#16a052}.miniStep span.active{color:#6d28d9;font-weight:800}
.switch{width:43px;height:25px;border-radius:20px;background:#20af5b;padding:4px;display:flex;justify-content:flex-end}.switch:after{content:"";width:17px;height:17px;border-radius:50%;background:white}.togglegray{background:#dddcea;justify-content:flex-start}
.fineprint{font-size:10.5px;color:#8b90a3;line-height:1.5}
body[data-screen="C028"] .card{padding:12px;margin-bottom:9px}
body[data-screen="C028"] .divrow{padding:8px 0}
body[data-screen="C011"] .card{margin-bottom:9px}
'''

RIDE_TRIP=f'''<div class="trip"><div class="stop"><div class="label">Điểm đón</div><div class="bold small">{R['pickup']}</div></div><div class="stop"><div class="label">Điểm đến</div><div class="bold small">{R['destination']}</div></div></div>'''
F_ITEMS=''.join(f'<div class="divrow"><img class="foodimg" style="width:48px;height:46px" src="../assets/food_bun.jpg"><div class="flex1 small bold">{x["name"]}<div class="label">Số lượng: {x["qty"]}</div></div><div class="small bold">{money(x["price"]*x["qty"])}</div></div>' for x in F['items'])

def bigfooter(text,secondary=None,color=''):
 if secondary:return f'<div class="row gap8"><div class="btn outline flex1">{secondary}</div><div class="btn flex1">{text}</div></div>'
 return f'<div class="btn {color}">{text} →</div>'
def render(name,title,body,cta=None,sub=None,nav=None,action=None):
 act=f'<div class="topaction">{action}</div>' if action else ''
 top=f'<div class="htext"><h1>{title}</h1>{f"<small>{sub}</small>" if sub else ""}</div>'
 navhtml=''
 if nav:
  tabs={'customer':[('⌂','Trang chủ'),('▤','Chuyến đi'),('⊞','Đặt'),('▣','Mua hàng'),('♙','Tài khoản')], 'merchant':[('⌂','Tổng quan'),('▤','Đơn hàng'),('▦','Sản phẩm'),('▥','Thống kê'),('♙','Tài khoản')], 'driver':[('⌂','Tổng quan'),('▤','Công việc'),('▥','Thu nhập'),('◉','Thông báo'),('♙','Tài khoản')] }[nav]
  selected={'customer':'Mua hàng','merchant':'Tổng quan','driver':'Tổng quan'}[nav]
  navhtml='<div class="nav">'+''.join(f'<div class="tab {"sel" if text==selected else ""}"><span>{icon}</span>{text}</div>' for icon,text in tabs)+'</div>'
  cta=None
 footer=f'<div class="footer">{cta}</div>' if cta else ''
 return f'''<!DOCTYPE html><html lang="vi"><head><meta charset="utf-8"><meta name="viewport" content="width=500,initial-scale=1"><title>{name} · DealGo Remediated</title><style>{css}</style></head><body data-screen="{name}"><div class="stage"><div class="phone"><div class="status"><div>9:41</div><div class="bars">▂ ▄ ▆ ᴡɪғɪ ▰</div></div><div class="header"><div class="back">‹</div>{top}{act}</div><div class="viewport"><div class="content {"withnav" if nav else ""}">{body}</div>{footer}{navhtml}</div><div class="homepill"></div></div></div></body></html>'''
def card(t,content,kind=''):return f'<section class="card {kind}"><div class="title mb8">{t}</div>{content}</section>'
def box(t,c):return f'<div class="metric"><div class="label">{t}</div><strong>{c}</strong></div>'
def write(id,title,body,cta=None,sub=None,nav=None,action=None):
 (S/f'{id}.html').write_text(render(id,title,body,cta,sub,nav,action),encoding='utf8')

# Ride golden path: one quote, one vehicle, one fare version.
write('C004','Chọn loại xe',
 card('Lộ trình của bạn',RIDE_TRIP) + '<div class="map smallmap"><div class="floating">Đà Nẵng · Hành trình dự kiến</div><div class="mapbottom">12 phút · ~5,2 km</div></div>'+
 card('Chọn phương tiện','<div class="item"><div class="logoicon green">♧</div><div class="flex1"><div class="bold">Xe máy</div><div class="label">Tiện lợi · 1 khách</div></div><div class="small bold">Từ 25.000đ</div></div>'+
 f'<div class="item" style="background:#f6f0ff;border-radius:14px;padding:10px;border:1.5px solid #a581e7"><div class="rideimg">🚘</div><div class="flex1"><div class="bold">Xe 4 chỗ <span class="pill">Đã chọn</span></div><div class="label">1–4 khách · Từ 12 phút</div><div class="money med">{money(R["payable"])}</div></div></div>'+
 '<div class="item"><div class="logoicon">🚙</div><div class="flex1"><div class="bold">Xe 7 chỗ</div><div class="label">Nhóm đông, nhiều hành lý</div></div><div class="small bold">Từ 65.000đ</div></div>')+
 '<div class="notice">Giá đang hiển thị là giá minh họa của phiên báo giá này, được xác nhận trước khi đặt xe.</div>',bigfooter('Xem giá chi tiết'))
write('C005','Chi tiết giá cước',
 card('Xe 4 chỗ · Toyota Vios', f'<div class="row"><div class="rideimg">🚘</div><div class="flex1"><div class="label">Phí dự kiến</div><div class="money">{money(R["payable"])}</div><span class="pill green">Phiên giá v{R["fareVersion"]}</span></div></div>','purple')+
 card('Cấu phần giá',f'<div class="divrow row between"><span>Cước mở cửa</span><strong>{money(R["fareOpening"])}</strong></div><div class="divrow row between"><span>Cước quãng đường</span><strong>{money(R["fareDistance"])}</strong></div><div class="divrow row between"><span>Phụ phí đã tính</span><strong>{money(R["fees"])}</strong></div><div class="divrow row between"><span>Ưu đãi</span><strong>{money(R["discount"])}</strong></div><div class="row between mt12"><span class="bold">Tổng giá đề xuất</span><span class="money">{money(R["payable"])}</span></div>')+
 card('Thông tin hành trình',RIDE_TRIP)+ '<div class="notice amber">Giá được chốt theo báo giá mà bạn xác nhận. Phụ phí phát sinh sau đó cần có thông báo và sự đồng ý của bạn.</div>',bigfooter('Đề xuất giá chuyến'))
write('C006','Tự đề xuất giá chuyến',
 card('Thông tin đặt xe',RIDE_TRIP + '<div class="line"></div><div class="row between small"><span>Xe 4 chỗ</span><span class="bold">~12 phút · 5,2 km</span></div>')+
 card('Mức giá bạn muốn đề xuất',f'<div class="label">Giá gợi ý từ DealGo</div><div class="money">{money(R["payable"])}</div><div class="line"></div><div class="label">Đề xuất của bạn</div><div class="input" style="text-align:center;color:var(--purple);font-size:29px;font-weight:900">{money(R["payable"])}</div><div class="grid3 mt12"><div class="pill">38.000đ</div><div class="pill" style="border:2px solid #7b39d5">42.000đ ✓</div><div class="pill">48.000đ</div></div>')+
 card('Thương lượng minh bạch','<div class="row start"><div class="logoicon green">↔</div><div class="subtitle">Tài xế có thể chào giá khác. Bạn chỉ trả số tiền trong báo giá đã chấp nhận.</div></div>')+
 '<div class="notice">Mã yêu cầu: RIDE_CAR_001 · Không tự tăng giá khi có tài xế phản hồi.</div>',bigfooter('Gửi đề xuất 42.000đ'))
write('C010','Đang nhận báo giá',
 card('Yêu cầu đang mở',RIDE_TRIP + f'<div class="line"></div><div class="row between"><span class="pill green">Đã gửi đề xuất</span><span class="money med">{money(R["payable"])}</span></div>')+
 '<div style="margin:28px auto 20px;width:180px;height:180px;border-radius:50%;display:grid;place-items:center;background:radial-gradient(circle,#f7efff 22%,#f6edff 24%,#e8d9ff 48%,#f4efff 50%,#f5f0ff 70%);font-size:65px">🚘</div>'+
 '<div class="title" style="text-align:center;font-size:22px">Đang chờ tài xế chào giá...</div><p class="subtitle" style="text-align:center;margin:10px 10px 20px">Những báo giá phù hợp sẽ xuất hiện để bạn so sánh và tự chọn tài xế.</p>'+
 card('Tiến trình','<div class="item"><span class="pill green">✓</span><span class="small">Đã gửi yêu cầu thành công</span></div><div class="item"><span class="pill">●</span><span class="small">Đang nhận báo giá từ tài xế</span></div><div class="item"><span class="pill gray">○</span><span class="small">Chờ bạn chọn và xác nhận</span></div>')
 ,bigfooter('Hủy tìm kiếm',color='outline'))
quote_list=[('Nguyễn Văn Hùng',42000,'4 phút','Toyota Vios','43A-567.89',4.9),('Trần Quốc Minh',45000,'6 phút','Hyundai Accent','43A-240.67',4.8),('Lê Hoàng Nam',48000,'8 phút','Kia Cerato','43A-981.15',4.7)]
qhtml=''
for idx,(driver,price,eta,car,plate,rating) in enumerate(quote_list):
 qhtml+=f'''<div class="card {"purple" if idx==0 else ""}"><div class="row"><div class="avatar">{driver.split()[-1][0]}</div><div class="flex1"><div class="bold">{driver}</div><div class="label">⭐ {rating} · {car}</div><div class="label">{plate} · Đến đón sau {eta}</div></div><div class="money med">{money(price)}</div></div><div class="row between mt12"><span class="pill {"green" if idx==0 else "gray"}">{"Bằng giá bạn đề xuất" if idx==0 else "Đề nghị khác"}</span><span class="pill">Xem chi tiết →</span></div></div>'''
write('C007','Tài xế chào giá',card('Hành trình & giá đề xuất',RIDE_TRIP + f'<div class="line"></div><div class="row between"><span class="small muted">Giá bạn đề xuất</span><b class="money med">{money(R["payable"])}</b></div>')+
 '<div class="row between mb8"><div class="title">3 báo giá phù hợp</div><span class="pill">Giá thấp nhất ▾</span></div>'+qhtml+'<div class="notice amber">Chỉ có báo giá bạn xác nhận mới tạo thành chuyến đi. Báo giá chưa chọn có thể hết hạn.</div>',bigfooter('Xem tài xế Nguyễn Văn Hùng'))
write('C008','Chi tiết tài xế',
 card('Tài xế được xác minh',f'<div class="row"><div class="avatar" style="width:72px;height:72px;font-size:28px">H</div><div class="flex1"><div class="title">{R["driver"]}</div><div class="label">⭐ 4,9 · 320 đánh giá</div><span class="pill green">✓ Hồ sơ hợp lệ</span></div></div><div class="line"></div><div class="row"><div class="rideimg">🚘</div><div class="col"><b>{R["vehicle"]}</b><span class="pill">{R["plate"]}</span><div class="label">Đến đón sau ~4 phút</div></div></div>')+
 card('Giá tài xế chào',f'<div class="row between"><span class="subtitle">Báo giá {R["quoteId"]} · phiên v{R["fareVersion"]}</span><span class="money">{money(R["payable"])}</span></div><div class="notice mt12">Giá trên đã gồm phần phí hiện có. Không tự động phát sinh giá mới khi xác nhận.</div>','purple')+
 card('Điểm đón và điểm đến',RIDE_TRIP)+card('An toàn chuyến đi','<div class="row"><div class="logoicon green">✓</div><div class="subtitle">Biển số và tài xế hiển thị lại trước khi lên xe; xác thực mã đón trước khi bắt đầu.</div></div>'),bigfooter('Chọn tài xế này'))
write('C009','Xác nhận chuyến xe',
 card('Hành trình đã chọn',RIDE_TRIP)+
 card('Tài xế và phương tiện',f'<div class="row"><div class="avatar">H</div><div class="flex1"><div class="bold">{R["driver"]}</div><div class="label">{R["vehicle"]}</div><span class="pill">{R["plate"]}</span></div><span class="pill green">⭐ 4,9</span></div>')+
 card('Báo giá được chốt',f'<div class="row between"><span class="small">Báo giá {R["quoteId"]}</span><span class="pill green">v{R["fareVersion"]} · Còn hiệu lực</span></div><div class="row between mt8"><span>Cước chuyến</span><b>{money(R["fareOpening"]+R["fareDistance"])}</b></div><div class="row between mt8"><span>Phụ phí</span><b>{money(R["fees"])}</b></div><div class="line"></div><div class="row between"><b>Khách thanh toán</b><b class="money">{money(R["payable"])}</b></div>','purple')+
 card('Phương thức thanh toán',f'<div class="row"><div class="logoicon green">♧</div><div class="flex1"><b>{R["paymentMethod"]}</b><div class="label">Chỉ thu tiền khi chuyến đi hoàn tất</div></div><span class="pill green">Đã chọn</span></div>')+
 '<div class="notice amber">Nếu giá thay đổi, DealGo sẽ yêu cầu bạn xem và xác nhận lại trước khi áp dụng.</div>',bigfooter('Xác nhận giá 42.000đ'))
write('C011','Tài xế đang đến đón',
 '<div class="map"><div class="floating">🚘 Tài xế còn khoảng 4 phút</div><div class="mapbottom">Đang di chuyển tới điểm đón</div></div>'+
 card('Tài xế đã nhận chuyến',f'<div class="row"><div class="avatar">H</div><div class="flex1"><b>{R["driver"]}</b><div class="label">⭐ 4,9 · {R["vehicle"]}</div><span class="pill">{R["plate"]}</span></div><div class="logoicon">☎</div></div>')+
 card('Thông tin chuyến đi',RIDE_TRIP + f'<div class="line"></div><div class="row between"><span class="small muted">Giá đã chốt · {R["quoteId"]}</span><span class="money med">{money(R["payable"])}</span></div>')+
 card('Mã đón khách','<div class="row between"><div><div class="label">Chỉ cung cấp mã khi xe đến đúng biển số</div><div class="title mt8" style="font-size:27px;letter-spacing:8px">7 2 9 4</div></div><div class="logoicon green">✓</div></div>'),bigfooter('Liên hệ tài xế',secondary='Chia sẻ chuyến đi'))

# Food transaction holds same order/amount across customer/shop/driver.
write('C028','Thanh toán đơn đồ ăn',
 card('Địa chỉ giao hàng','<div class="row"><div class="logoicon green">⌖</div><div class="flex1"><b>Nhà · Đà Nẵng</b><div class="label">123 Đường Bạch Đằng, Hải Châu</div></div><span class="pill">Đổi</span></div>')+
 card(F['shop'],f'<div class="row"><img class="foodimg" src="../assets/food_bun.jpg"><div class="flex1"><div class="bold">Đơn #{F["orderId"]}</div><div class="subtitle">3 món · Hình thức giao: Tiêu chuẩn</div><span class="pill green">Quán nhận đơn sau xác nhận</span></div></div><div class="line"></div>'+F_ITEMS)+
 card('Tổng thanh toán',f'<div class="row between"><span class="small">Tạm tính</span><b>{money(F["subtotal"])}</b></div><div class="row between mt8"><span class="small">Phí giao hàng</span><b>{money(F["deliveryFee"])}</b></div><div class="row between mt8"><span class="small">Giảm giá</span><b>{money(F["discount"])}</b></div><div class="line"></div><div class="row between"><b>Khách cần thanh toán</b><b class="money">{money(F["payable"])}</b></div>','purple')+
 '<div class="notice amber">COD · Chưa thu tiền. Chỉ xác nhận thanh toán khi tài xế thu tiền và hệ thống ghi nhận giao hàng thành công.</div>',bigfooter('Đặt hàng · 150.000đ'))
write('M016','Chi tiết đơn mới',
 '<div class="row between mb8"><span class="pill orange">Mới nhận · Chờ xác nhận</span><span class="pill gray">#DG123456</span></div>'+
 card('Khách hàng',f'<div class="row"><div class="avatar">M</div><div class="flex1"><b>{F["customer"]}</b><div class="label">Giao tận nơi · Thanh toán COD</div></div><span class="pill">13:24</span></div>')+
 card('Danh sách món',F_ITEMS)+
 card('Đối soát đơn',f'<div class="row between"><span>Tiền món</span><b>{money(F["subtotal"])}</b></div><div class="row between mt8"><span>Phí giao khách trả</span><b>{money(F["deliveryFee"])}</b></div><div class="row between mt8"><span>Khách thanh toán COD</span><b>{money(F["payable"])}</b></div><div class="line"></div><div class="row between"><b>Doanh thu món (trước điều chỉnh)</b><b class="money med">{money(F["merchantGross"])}</b></div>','purple')+
 '<div class="notice amber">COD chưa thu. Shop không được đánh dấu “Đã thanh toán” trước khi có giao dịch được xác nhận từ hệ thống.</div>',bigfooter('Xác nhận đơn',secondary='Từ chối'))
write('D030','Hoàn tất giao hàng',
 '<div style="text-align:center;margin:10px 0 22px"><div style="width:92px;height:92px;border-radius:50%;background:#e2f9e7;color:#0fa34f;font-size:55px;display:grid;place-items:center;margin:auto">✓</div><div class="title mt12" style="font-size:22px">Đã xác nhận giao hàng</div><p class="subtitle">Đơn #DG123456 · Đã ghi nhận bởi hệ thống</p></div>'+
 card('Đơn đã hoàn tất',f'<div class="row"><img class="foodimg" src="../assets/food_bun.jpg"><div class="flex1"><b>{F["shop"]}</b><div class="label">3 món · Khách: {F["customer"]}</div></div><span class="pill green">Đã giao</span></div>')+
 card('Thanh toán tiền mặt (COD)',f'<div class="row between"><span>Tiền món</span><b>{money(F["subtotal"])}</b></div><div class="row between mt8"><span>Đã thu từ khách</span><span class="money">{money(F["payable"])}</span></div><div class="row between mt12"><span>Thu nhập chuyến giao</span><b class="greentext">{money(F["driverEarnings"])}</b></div><div class="row between mt8"><span>Cần đối soát lại</span><b>{money(F["driverCashToReconcile"])}</b></div><div class="line"></div><div class="notice">{money(F["payable"])} là tiền thu hộ, KHÔNG phải toàn bộ thu nhập của tài xế.</div>','purple')+
 card('Bằng chứng giao hàng','<div class="row"><div class="logoicon green">✓</div><div class="flex1"><b>Xác minh giao thành công</b><div class="label">Dữ liệu POD/OTP được lưu trong phiên đơn</div></div></div>'),bigfooter('Về Dashboard tài xế'))
write('S007','Trung tâm vai trò',
 '<div class="brand" style="text-align:center;margin:16px 0 10px"><span class="p">Deal</span><span class="g">Go</span></div><p class="subtitle" style="text-align:center;margin:0 0 20px">Một tài khoản · Ba chế độ vận hành</p>'+
 card('Chế độ Khách hàng','<div class="row"><div class="logoicon">♙</div><div class="flex1"><div class="bold">Đặt xe, đồ ăn và mua hàng</div><div class="label">Sử dụng dịch vụ DealGo</div></div><span class="pill green">Đang xem</span></div>','purple')+
 card('Chế độ Shop','<div class="row"><div class="logoicon green">▣</div><div class="flex1"><b>Quản lý cửa hàng</b><div class="label">Đơn mới · Menu · Doanh thu</div></div><span class="pill">Chuyển →</span></div>')+
 card('Chế độ Tài xế','<div class="row"><div class="logoicon orange">🚲</div><div class="flex1"><b>Chở khách và giao món</b><div class="label">Nhận việc · Điều hướng · Thu nhập</div></div><span class="pill">Chuyển →</span></div>')+
 '<div class="notice">Đổi chế độ chỉ thay đổi giao diện và quyền thao tác. Đơn Shop hoặc công việc Tài xế đang chạy vẫn giữ nguyên trạng thái trên hệ thống.</div>'+
 card('Thông báo xuyên vai trò','<div class="row"><div class="logoicon">🔔</div><div class="flex1"><div class="bold">Có 2 công việc cần theo dõi</div><div class="label">Thông báo đưa bạn về đúng vai trò khi mở</div></div></div>'),bigfooter('Tiếp tục với Khách hàng'))
write('M013','Tổng quan cửa hàng',
 '<div class="row between mb8"><div class="row"><img class="foodimg" style="width:53px;height:53px" src="../assets/food_bun.jpg"><div><b>Bún Bò Huế O Cô</b><div class="label">Đà Nẵng · Chi nhánh chính</div></div></div><span class="pill green">Đang mở</span></div>'+
 '<div class="grid2 mb8">'+box('Đơn cần xác nhận','03')+box('Đang chuẩn bị','05')+box('Đã hoàn thành','24')+box('Tiền món hôm nay','3.125.000đ')+'</div>'+
 card('Đơn cần xử lý',f'<div class="row"><img class="foodimg" src="../assets/food_bun.jpg"><div class="flex1"><div class="bold">#{F["orderId"]} · {F["customer"]}</div><div class="label">3 món · {money(F["subtotal"])} tiền món</div><span class="pill orange">Chưa xác nhận</span></div><span class="pill">Xem →</span></div><div class="line"></div><div class="row between"><span class="small">Đơn khác · #DG123457</span><span class="pill orange">Đang chuẩn bị</span></div>')+
 card('Tài chính hôm nay','<div class="row between"><span class="subtitle">Doanh thu món (gross)</span><b>3.125.000đ</b></div><div class="row between mt8"><span class="subtitle">Số tiền chờ quyết toán</span><b>820.000đ</b></div><div class="row between mt8"><span class="subtitle">Số dư khả dụng</span><b class="greentext">2.305.000đ</b></div>')+
 '<div class="notice">Doanh thu không đồng nghĩa số dư có thể rút; COD và hoàn tiền được đối soát riêng.</div>',nav='merchant')
write('D016','Tổng quan tài xế',
 '<div class="row between mb8"><div class="row"><div class="avatar">A</div><div><b>Trần Minh Anh</b><div class="label">Honda Vision · 43H1-123.45</div></div></div><span class="pill green">● Online</span></div>'+
 '<div class="map smallmap"><div class="floating">📍 Hải Châu · Đà Nẵng</div><div class="mapbottom">Khu vực hoạt động</div></div>'+
 '<div class="grid2 mb8">'+box('Chuyến hoàn thành','12')+box('Thu nhập thực nhận','1.250.000đ')+box('Đánh giá trung bình','⭐ 4,9')+box('Thời gian hoạt động','2 giờ 30 phút')+'</div>'+
 card('Dịch vụ được phép nhận','<div class="row between"><div class="row"><div class="logoicon green">🛵</div><div><b>Chở khách</b><div class="label">Xe máy · Đã duyệt</div></div></div><div class="switch"></div></div><div class="line"></div><div class="row between"><div class="row"><div class="logoicon orange">🥡</div><div><b>Giao đồ ăn</b><div class="label">Đã đủ điều kiện</div></div></div><div class="switch"></div></div>')+
 '<div class="notice">Giá và quyền nhận chuyến được kiểm tra bởi hệ thống. Tài xế chỉ có một công việc đang thực hiện tại một thời điểm.</div>',nav='driver')

write('D036','COD cần đối soát',
 card('Ví dụ một đơn COD',f'<div class="row between"><span class="bold">Đơn #{F["orderId"]}</span><span class="pill orange">Chờ đối soát</span></div><div class="label mt8">{F["shop"]} · Giao cho {F["customer"]}</div><div class="line"></div><div class="row between"><span>Thu hộ từ khách</span><b class="money">{money(F["payable"])}</b></div>','purple')+
 card('Phân bổ giao dịch',f'<div class="row between"><span>Tiền món của Shop</span><b>{money(F["merchantNet"])}</b></div><div class="row between mt8"><span>Phí nền tảng từ giao hàng</span><b>{money(F["platformDeliveryFee"])}</b></div><div class="row between mt8"><span>Thu nhập thực của tài xế</span><b class="greentext">{money(F["driverEarnings"])}</b></div><div class="line"></div><div class="row between"><span>Tiền cần nộp/đối soát</span><b class="money med">{money(F["driverCashToReconcile"])}</b></div>')+
 '<div class="notice amber">Tiền COD giữ hộ không được ghi tăng vào ví thu nhập. Chỉ thay đổi trạng thái “Đã đối soát” khi ledger backend xác nhận.</div>'+
 card('Trạng thái xử lý','<div class="item"><span class="pill green">✓</span><span>Đã xác minh giao thành công</span></div><div class="item"><span class="pill green">✓</span><span>Đã thu 150.000đ từ khách</span></div><div class="item"><span class="pill orange">…</span><span>Chưa đối soát 130.000đ</span></div>'),bigfooter('Xem hướng dẫn đối soát'))
write('M035','Danh sách quyết toán',
 card('Khoản thu của cửa hàng',f'<div class="row between"><div><div class="label">Đơn #{F["orderId"]}</div><div class="title">{F["shop"]}</div></div><span class="pill orange">COD chờ đối soát</span></div><div class="line"></div><div class="row between"><span>Tiền món</span><b>{money(F["merchantGross"])}</b></div><div class="row between mt8"><span>Phí vận chuyển từ khách</span><b>{money(F["deliveryFee"])}</b></div><div class="row between mt8"><span>COD khách đã đưa tài xế</span><b>{money(F["payable"])}</b></div><div class="row between mt8"><span>Công nợ đến Shop (ví dụ)</span><b class="money med">{money(F["merchantNet"])}</b></div>','purple')+
 card('Trạng thái payout','<div class="item"><span class="pill green">✓</span><span>Đã ghi nhận giao thành công</span></div><div class="item"><span class="pill orange">…</span><span>Chờ xác nhận đối soát COD</span></div><div class="item"><span class="pill gray">○</span><span>Chưa chuyển tiền về tài khoản Shop</span></div>')+
 '<div class="notice">Tổng tiền khách thanh toán 150.000đ bao gồm 125.000đ tiền món và 25.000đ phí giao hàng; Shop không nhận toàn bộ 150.000đ.</div>',bigfooter('Xem lịch sử quyết toán'))

if __name__=='__main__':print('Generated',len(list(S.glob('*.html'))),'HTML sources')
