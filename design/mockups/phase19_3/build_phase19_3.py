from pathlib import Path
import importlib.util,json,html,shutil
ROOT=Path(__file__).parent; S=ROOT/'screens'; A=ROOT/'assets'; D=ROOT/'docs'
for p in (S,A,D):p.mkdir(parents=True,exist_ok=True)
spec=importlib.util.spec_from_file_location('original_style','/mnt/data/dealgo_phase19/build_phase19.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
m.S=S
m.css+='''
body .card{padding:12px 13px;margin-bottom:9px;border-radius:17px}
body .card .title{font-size:15px;margin-bottom:7px}
body .divrow{padding:8px 0}
body .item{padding:8px 0}
body .content{padding-top:12px}
body .notice{padding:9px 11px;margin-bottom:8px}
body .metric{padding:10px}
body .metric strong{font-size:15px}
body .content .map{margin-bottom:8px}
body .content .map.smallmap{height:160px}
body .fineprint{margin-top:8px}
body .card .money{font-size:23px}
body .card .money.med{font-size:20px}
body .label{font-size:10.5px}
body .subtitle{font-size:11px}
body .pill{font-size:10px}
body .footer .btn{font-size:13px}
'''
for fn in ('food_bun.jpg','danang_route_map.png'):
 shutil.copy2(Path('/mnt/data/dealgo_phase19/assets')/fn,A/fn)
F={
 'orderId':'DG123456','draftCartId':'CART-014','orderVersion':1,'quoteId':'SHIP-Q-014','quoteVersion':1,
 'shopId':'SHOP-OCO-01','shop':'Bún Bò Huế O Cô','shopLocation':'123 Lê Lợi, Hải Châu, Đà Nẵng',
 'customer':'Trần Thị Mai','customerLocation':'456 Trần Hưng Đạo, Sơn Trà, Đà Nẵng',
 'driver':'Trần Minh Anh','vehicle':'Honda Vision · xe máy','plate':'43H1-123.45',
 'items':[{'name':'Bún bò đặc biệt','qty':1,'unitPrice':60000},{'name':'Bún bò thường','qty':1,'unitPrice':40000},{'name':'Trà tắc','qty':1,'unitPrice':25000}],
 'subtotal':125000,'deliveryFee':25000,'discount':0,'payable':150000,
 'driverEarning':20000,'platformDeliveryFee':5000,'merchantReceivable':125000,
 'cashToReconcile':130000,'paymentMethod':'COD'
}
assert sum(x['qty']*x['unitPrice'] for x in F['items'])==F['subtotal']
assert F['subtotal']+F['deliveryFee']-F['discount']==F['payable']
assert F['deliveryFee']==F['driverEarning']+F['platformDeliveryFee']
assert F['merchantReceivable']+F['platformDeliveryFee']==F['cashToReconcile']
assert F['payable']==F['cashToReconcile']+F['driverEarning']
(D/'golden_order.json').write_text(json.dumps(F,ensure_ascii=False,indent=2),encoding='utf-8')
M=m.money
fmt=M
h=lambda s:html.escape(str(s))
def status(label,kind='green'):return f'<span class="pill {kind}">{h(label)}</span>'
def row(a,b,cls=''):return f'<div class="row between mt8 {cls}"><span class="small">{a}</span><b>{b}</b></div>'
def summary(show_breakdown=True):
 x=row('Tiền món',M(F['subtotal']))+row('Phí giao',M(F['deliveryFee']))+row('Giảm giá',M(F['discount']))
 return x+('<div class="line"></div>'+row('Tổng COD',f'<span class="money med">{M(F["payable"])}</span>') if show_breakdown else '')
def items():return ''.join(f'<div class="item"><img class="foodimg" style="width:47px;height:45px" src="../assets/food_bun.jpg"><div class="flex1"><div class="bold small">{h(x["name"])}</div><div class="label">x{x["qty"]} · {M(x["unitPrice"])} / món</div></div><b class="small">{M(x["qty"]*x["unitPrice"])}</b></div>' for x in F['items'])
def draftref():return '<div class="row between"><span class="small bold">Giỏ hàng CART-014</span><span class="pill gray">Chưa tạo đơn</span></div>'
def ref():return f'<div class="row between"><div class="small bold">Đơn #{F["orderId"]}</div>{status("v1 · Dữ liệu đồng bộ","gray")}</div>'
def merchant():return f'<div class="row"><img class="foodimg" style="width:51px;height:49px" src="../assets/food_bun.jpg"><div class="flex1"><b>{h(F["shop"])}</b><div class="label">{h(F["shopLocation"])}</div></div></div>'
def driver():return f'<div class="row"><div class="avatar">A</div><div class="flex1"><b>{h(F["driver"])}</b><div class="label">{h(F["vehicle"])} · {h(F["plate"])}</div></div>{status("Xác minh hợp lệ")}</div>'
def customer():return f'<div class="row"><div class="avatar">M</div><div class="flex1"><b>{h(F["customer"])}</b><div class="label">{h(F["customerLocation"])}</div></div></div>'
def path_card():return m.card('Điểm nhận và giao',f'<div class="trip"><div class="stop"><div class="label">Điểm lấy món</div><div class="bold small">{h(F["shopLocation"])}</div></div><div class="stop"><div class="label">Giao cho khách</div><div class="bold small">{h(F["customerLocation"])}</div></div></div>')
def mapbox(lbl,mini=True):return f'<div class="map {"smallmap" if mini else ""}"><div class="floating">{lbl}</div><div class="mapbottom">Đà Nẵng · Mô phỏng</div></div>'
def info(s,kind=''):return f'<div class="notice {kind}">{s}</div>'
def C(title,text,kind=''):return m.card(title,text,kind)
def footer(label,secondary=None):return m.bigfooter(label,secondary=secondary)
def W(id,title,body,action=None,nav=None):m.write(id,title,body,footer('Tiếp tục') if False else None,nav=nav,action=action)
def screen(id,title,body,cta,secondary=None,nav=None):m.write(id,title,body,footer(cta,secondary),nav=nav)

# Customer; each screenshot depicts a deliberate event/time, not one frozen state.
screen('C027','Giỏ hàng',
 C('Bún Bò Huế O Cô',merchant()+items())+C('Dự tính thanh toán',summary())+
 info('Giỏ hàng đang ở trạng thái DRAFT. Chưa tạo đơn và chưa thu COD.')+
 C('Địa chỉ nhận',f'<div class="small">{F["customerLocation"]}</div>'),'Tiếp tục thanh toán')
screen('C028','Thanh toán đơn đồ ăn',
 C('Người nhận và địa chỉ',customer())+C('Danh sách món',merchant()+items())+
 C('Tổng thanh toán',summary(),'purple')+C('Thanh toán',status('COD · Chưa thu tiền','orange')+'<div class="subtitle mt8">Không ghi thanh toán thành công tại bước đặt đơn.</div>'),
 'Đặt hàng · 150.000đ')
screen('C030','Đề xuất phí giao hàng',
 C('Giá giao trước khi tạo đơn',draftref()+row('Phí giao gợi ý',M(F['deliveryFee']))+row('Phí giao bạn đề xuất',f'<span class="money med">{M(F["deliveryFee"])}</span>'),'purple')+
 C('Phương thức báo giá',f'<div class="item">{status("Mức đề xuất 25.000đ")}&nbsp; Phù hợp giá gợi ý</div><div class="label">Mã báo giá: {F["quoteId"]} · phiên v{F["quoteVersion"]}</div>')+
 C('Tạm tính đơn',summary())+info('Đây là đề xuất phí giao. Báo giá chỉ có hiệu lực khi khách xác nhận, Shop nhận đơn và tài xế được phân công.'),
 'Gửi đề xuất 25.000đ')
screen('C031','Tài xế báo giá giao',
 C('Yêu cầu giao đồ ăn',draftref()+row('Phí bạn đề xuất',M(F['deliveryFee']))+row('Quán',F['shop']))+
 C('Báo giá phù hợp',driver()+row('Phí giao chào',f'<span class="money med">{M(F["deliveryFee"])}</span>')+row('Ước tính đến quán','5 phút'))+
 C('Dự toán checkout',summary())+info('Chỉ chọn một báo giá. Chọn báo giá không đồng nghĩa tài xế đã nhận hàng; đơn còn phải được Shop xác nhận.'),
 'Chọn báo giá · 25.000đ')
screen('C032','Đã gửi đơn hàng',
 '<div style="text-align:center;margin:8px 0 14px"><div style="font-size:61px;color:#16a34a">✓</div><div class="title" style="font-size:22px">Đặt hàng thành công</div><div class="subtitle">Đơn đã được tạo; quán chưa xác nhận</div></div>'+
 C('Đơn hàng',ref()+merchant()+row('Khách thanh toán COD',M(F['payable']))+status('COD · Chưa thu tiền','orange'),'purple')+
 C('Tiến trình', '<div class="item">'+status('✓ Đơn đã gửi')+'<span class="small">13:24</span></div><div class="item">'+status('● Chờ Shop xác nhận','orange')+'</div><div class="item">'+status('○ Chưa chuẩn bị','gray')+'</div>')+
 info('“Đặt hàng thành công” là tạo đơn thành công, KHÔNG phải giao hàng hoặc thanh toán thành công.'),
 'Theo dõi đơn hàng')
screen('C033','Theo dõi đơn đồ ăn',
 C('Trạng thái thực tế',ref()+status('Đang giao đến bạn')+row('Quán',F['shop'])+row('Đã lấy món','13:47')+row('Đang giao','13:48'))+
 mapbox('🛵 Đơn đang được giao')+C('Tài xế đang giao',driver()+row('ETA minh họa','~8 phút'))+
 C('Thanh toán lúc nhận hàng',row('COD cần thanh toán',f'<span class="money med">{M(F["payable"])}</span>')+'<div class="label mt8">Chưa thu tiền cho đến khi giao thành công.</div>','purple'),
 'Liên hệ tài xế')
screen('C034','Duyệt đề nghị thay món',
 C('Shop đề nghị thay món',ref()+status('Chờ khách duyệt','orange')+'<div class="label mt8">Món “Trà tắc” tạm hết. Đề nghị đổi sang nước chanh cùng giá.</div>')+
 C('Thay thế được đề xuất',row('Món ban đầu','Trà tắc · 25.000đ')+row('Món thay thế','Nước chanh · 25.000đ')+row('Chênh lệch','0đ'))+
 C('Tiền vẫn giữ nguyên',summary(),'purple')+
 info('Nhánh ngoại lệ: đơn chỉ tăng version sau khi bạn đồng ý. Nếu từ chối, Shop tiếp tục xử lý hoặc hoàn/huỷ theo chính sách.'),
 'Đồng ý thay món',secondary='Từ chối')
screen('C035','Hủy đơn và lý do',
 C('Xác nhận yêu cầu hủy',ref()+status('Điều kiện theo trạng thái đơn','orange'))+
 C('Chọn lý do','<div class="item">◉ Đặt nhầm món</div><div class="item">○ Chờ quá lâu</div><div class="item">○ Thay đổi nhu cầu</div>')+
 C('Tác động tới thanh toán',row('COD đã thu','0đ')+row('Số tiền hoàn COD','0đ')+'<div class="label mt8">Nếu món đã chuẩn bị hoặc tài xế đã lấy, chính sách hủy và phí sẽ được xác định lại.</div>')+
 info('Nhánh ngoại lệ từ thời điểm chờ Shop xác nhận, không phải trạng thái của đơn đang giao trong luồng chính.'),
 'Gửi yêu cầu hủy',secondary='Giữ đơn')
screen('C036','Biên nhận đơn hàng',
 C('Đã giao thành công',ref()+status('DELIVERED · 15:05')+row('Quán',F['shop'])+row('Người nhận',F['customer']))+
 C('Món đã nhận',items())+C('Biên nhận',summary()+row('Phương thức','COD · Đã thu'),'purple')+
 info('Số tiền COD 150.000đ do tài xế thu và được ghi nhận một lần khi hoàn tất giao.'),
 'Đánh giá đơn hàng')
screen('C037','Đánh giá đơn hàng',
 C('Đơn đã giao',ref()+merchant()+row('Tổng đã thanh toán',M(F['payable'])))+
 C('Đánh giá món và quán','<div style="font-size:28px;text-align:center;color:#f7b520;margin:12px">★ ★ ★ ★ ★</div><div class="input">Món ăn ngon, đóng gói cẩn thận…</div>')+
 C('Đánh giá tài xế',driver()+'<div style="font-size:27px;color:#f7b520;text-align:center;margin:10px">★ ★ ★ ★ ★</div>')+
 info('Chỉ đánh giá sau trạng thái DELIVERED; không ghi nhận thanh toán lại khi gửi đánh giá.'),
 'Gửi đánh giá')

# Shop – single order lifecycle, no artificial early-paid status.
screen('M015','Hàng đợi đơn của Shop',
 C('Bún Bò Huế O Cô',merchant()+row('Đơn mới cần xác nhận','01'))+
 C('Đơn cần xử lý',ref()+status('NEW · Chờ Shop xác nhận','orange')+row('Khách',F['customer'])+row('3 món',M(F['subtotal']))+row('COD khách trả',M(F['payable'])),'purple')+
 C('Hàng đợi khác','<div class="item">'+status('Đang chế biến')+'<div class="small">Đơn #DG123457</div></div>')+
 info('Shop chỉ được xác nhận đơn thuộc cửa hàng đang quản lý; phân quyền kiểm tra tại backend.'),
 'Xem đơn DG123456')
screen('M016','Chi tiết đơn mới',
 C('Đơn chờ xác nhận',ref()+customer()+status('Chưa chuẩn bị','orange'))+
 C('Danh sách món',items())+C('Giá trị đơn',summary()+row('Doanh thu tiền món',M(F['merchantReceivable'])),'purple')+
 info('Shop không nhận toàn bộ 150.000đ: 25.000đ là phí giao; COD chưa thu tại bước này.'),
 'Xác nhận đơn',secondary='Từ chối')
screen('M017','Đơn đang chuẩn bị',
 C('Đơn đã nhận',ref()+status('PREPARING')+row('Giờ bắt đầu','13:30')+row('Dự kiến xong','13:45'))+
 C('Món cần chuẩn bị',items())+
 C('Trạng thái bếp','<div class="item">'+status('✓')+'Bún bò đặc biệt · Đã xong</div><div class="item">'+status('●','orange')+'Bún bò thường · Đang làm</div><div class="item">'+status('●','orange')+'Trà tắc · Đang làm</div>')+
 info('Chỉ đánh dấu READY_FOR_PICKUP khi đã đủ món và có thể bàn giao.'),
 'Đã chuẩn bị xong')
screen('M018','Đề nghị thay món',
 C('Món hiện không có',ref()+status('Chờ khách duyệt','orange')+row('Món cũ','Trà tắc · 25.000đ')+row('Thay bằng','Nước chanh · 25.000đ'))+
 C('Giá sau đề xuất',summary()+'<div class="label mt8">Giá không thay đổi vì hai món cùng giá.</div>','purple')+
 C('Kết quả đề xuất','<div class="item">'+status('○','gray')+'Đã gửi yêu cầu · chờ khách phản hồi</div><div class="item">'+status('○','gray')+'Chưa cập nhật đơn và tồn kho</div>')+
 info('Đây là nhánh điều chỉnh v2 đang chờ đồng ý, không sửa snapshot v1 đã chốt.'),
 'Gửi cho khách duyệt')
screen('M019','Bàn giao cho tài xế',
 C('Đơn đã sẵn sàng',ref()+status('READY_FOR_PICKUP')+merchant())+
 C('Tài xế nhận món',driver())+
 C('Đối chiếu khi giao',row('Mã bàn giao','2891')+row('Số túi','2 túi')+row('Tổng số món','3 món')+row('Số tiền COD','150.000đ'),'purple')+
 info('Shop xác nhận đã bàn giao cùng mã 2891; tài xế phải xác nhận nhận đủ hàng để chuyển sang PICKED_UP.'),
 'Đã bàn giao hàng')

# Driver, keeping dispatch quote / assignment separate from item readiness.
screen('D018','Yêu cầu đang mở',
 C('Khu vực nhận việc',f'<div class="row between"><span>Đà Nẵng · Hải Châu</span>{status("Online")}</div>')+
 C('Giao đồ ăn có thể nhận',ref()+merchant()+row('Giá giao được chấp nhận',M(F['deliveryFee']))+row('Dự kiến thu nhập tài xế',M(F['driverEarning']))+'<div class="label mt8">Chỉ được nhận sau khi Shop xác nhận và tài xế đủ điều kiện.</div>','purple')+
 C('Chế độ nhận việc','<div class="item">'+status('Giao đồ ăn')+'<span class="small">Đã bật · Hồ sơ hợp lệ</span></div>')+
 info('Một tài xế chỉ nhận tối đa một công việc đang thực hiện.'),
 'Xem chi tiết công việc')
screen('D019','Chi tiết yêu cầu giao món',
 C('Thông tin việc',ref()+merchant()+row('Phí giao khách thanh toán',M(F['deliveryFee']))+row('Thu nhập tài xế dự kiến',M(F['driverEarning'])),'purple')+
 path_card()+C('Thông tin tài chính',row('COD cần thu khi giao',M(F['payable']))+row('Tiền giữ lại sau đối soát',M(F['driverEarning']))+row('COD dự kiến phải nộp',M(F['cashToReconcile'])))+
 info('Khoản COD 150.000đ là tiền thu hộ; không phải doanh thu cá nhân.'),
 'Nhận việc',secondary='Bỏ qua')
screen('D020','Thương lượng phí giao',
 C('Báo giá của khách',ref()+row('Phí giao đề nghị',M(F['deliveryFee']))+row('Mã báo giá',F['quoteId']))+
 C('Chào giá của bạn',f'<div class="input" style="font-size:23px;text-align:center;color:#6d28d9;font-weight:900">{M(F["deliveryFee"])}</div><div class="label mt8">Chưa đổi báo giá khi khách chưa đồng ý.</div>','purple')+
 C('Nếu báo giá được chấp nhận',row('Phí giao khách trả',M(F['deliveryFee']))+row('Thu nhập tài xế dự kiến',M(F['driverEarning'])))+
 info('Bất kỳ counteroffer giá khác 25.000đ sẽ tạo quoteVersion mới và bắt buộc khách xác nhận trước khi cập nhật tổng COD.'),
 'Gửi báo giá')
screen('D026','Đến cửa hàng nhận món',
 mapbox('🛵 Đang đến quán')+C('Điểm lấy hàng',merchant()+row('Đơn hàng','#DG123456')+row('ETA minh họa','5 phút'))+
 C('Trạng thái bếp',status('Đang chuẩn bị','orange')+'<div class="label mt8">Báo cho Shop khi bạn đã tới nơi; chưa xác nhận đã lấy món.</div>'),
 'Tôi đã đến quán')
screen('D027','Tại quán chờ món',
 C('Đơn đang chờ lấy',ref()+merchant()+status('Chờ Shop đóng gói','orange'))+
 C('Tiến trình','<div class="item">'+status('✓')+'Tài xế đã đến quán</div><div class="item">'+status('●','orange')+'Shop đang hoàn thiện món</div><div class="item">'+status('○','gray')+'Chưa đối chiếu mã bàn giao</div>')+
 C('Khi Shop hoàn tất',row('Số món cần kiểm','3 món')+row('Dự kiến số túi','2 túi'))+
 info('Không bật “Bắt đầu giao” trước khi Shop và tài xế xác nhận bàn giao hợp lệ.'),
 'Liên hệ Shop',secondary='Báo chậm')
screen('D028','Xác nhận lấy món',
 C('Mã bàn giao',ref()+f'<div style="font-size:38px;text-align:center;font-weight:900;color:#6d28d9;padding:7px">2 8 9 1</div>'+status('Shop đã xác nhận READY_FOR_PICKUP'))+
 C('Kiểm tra món hàng',items()+row('Số túi bàn giao','2 túi'))+
 C('Xác minh đúng đơn',row('Quán',F['shop'])+row('COD sẽ thu lúc giao',M(F['payable'])))+
 info('Chỉ sau khi xác nhận mã 2891 và đủ món, trạng thái mới chuyển sang PICKED_UP.'),
 'Xác nhận đã lấy món')
screen('D029','Đang giao đến khách',
 mapbox('🛵 Đang giao · ~8 phút')+C('Người nhận',customer()+row('Đơn','#DG123456')+row('COD phải thu',f'<span class="money med">{M(F["payable"])}</span>'),'purple')+
 C('Bằng chứng giao',status('Chưa giao','orange')+'<div class="label mt8">Xác thực OTP hoặc bằng chứng giao hàng phù hợp trước khi xác nhận thành công.</div>'),
 'Đã đến điểm giao')
screen('D030','Xác nhận giao thành công',
 '<div style="text-align:center;margin:0 0 10px"><div style="font-size:53px;color:#16a34a">✓</div><div class="title">Đã giao thành công</div><div class="subtitle">Đơn #DG123456 · trạng thái DELIVERED</div></div>'+
 C('Thông tin giao',customer()+merchant())+
 C('Tiền thu hộ COD',row('Đã thu từ khách',f'<span class="money med">{M(F["payable"])}</span>')+row('Tiền món Shop',M(F['merchantReceivable']))+row('Thu nhập tài xế',M(F['driverEarning']))+row('COD cần đối soát',M(F['cashToReconcile'])),'purple')+
 C('Bằng chứng',status('✓ Đã xác minh giao')+'<div class="label mt8">Ghi nhận một lần bằng transaction ID/idempotency key.</div>')+
 info('Thu hộ 150.000đ không có nghĩa tài xế nhận thu nhập 150.000đ.'),
 'Về trang chủ')
screen('D031','Xử lý giao thất bại',
 C('Báo cáo ngoại lệ',ref()+status('DELIVERY_FAILED','red')+row('Khách hàng',F['customer']))+
 C('Chọn nguyên nhân','<div class="item">◉ Không liên lạc được với khách</div><div class="item">○ Khách từ chối nhận</div><div class="item">○ Địa chỉ không chính xác</div><div class="item">○ Hàng bị hư hỏng</div>')+
 C('Tình trạng tiền mặt',row('COD đã thu','0đ')+row('COD đang giữ','0đ')+row('Đơn hàng','Chưa hoàn tất'))+
 info('Nhánh thất bại: không ghi DELIVERED, không ghi COD collected; hàng cần được hoàn/điều phối theo quyết định hệ thống.'),
 'Báo sự cố và chờ hướng dẫn')
screen('D036','Đối soát COD tài xế',
 C('Đã giao và thu hộ',ref()+status('DELIVERED · COD_COLLECTED')+row('Tiền đã thu khách',f'<span class="money med">{M(F["payable"])}</span>'),'purple')+
 C('Phân bổ COD',row('Tiền món của Shop',M(F['merchantReceivable']))+row('Phí nền tảng',M(F['platformDeliveryFee']))+row('Thu nhập tài xế được giữ',M(F['driverEarning']))+'<div class="line"></div>'+row('COD cần nộp/đối soát',M(F['cashToReconcile'])))+
 C('Trạng thái ledger',status('PENDING_RECONCILIATION','orange')+'<div class="label mt8">Chỉ backend chuyển COMPLETED khi tiền được đối soát, không cập nhật bằng thao tác cục bộ.</div>'),
 'Xem chi tiết đối soát')
screen('M035','Đối soát doanh thu Shop',
 C('Đơn giao hoàn tất',ref()+merchant()+status('DELIVERED · Chờ quyết toán','orange'))+
 C('Tiền của đơn',row('Khách đã thanh toán COD',M(F['payable']))+row('Tiền món được ghi nhận',M(F['merchantReceivable']))+row('Phí giao không thuộc Shop',M(F['deliveryFee'])),'purple')+
 C('Dòng tiền đang xử lý',status('PENDING_RECONCILIATION','orange')+'<div class="label mt8">Shop nhận 125.000đ tiền món trước các khoản phí Shop thực tế khác (nếu có).</div>')+
 info('Không đánh dấu “đã chuyển khoản” khi COD mới chỉ được tài xế thu; chờ backend payout confirm.'),
 'Xem chi tiết quyết toán')

IDS=sorted(x.stem for x in S.glob('*.html'))
assert len(IDS)==26,len(IDS)
(D/'patch_ids.json').write_text(json.dumps(IDS,ensure_ascii=False,indent=2),encoding='utf8')
print('GENERATED',len(IDS), IDS)
