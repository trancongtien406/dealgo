from pathlib import Path
import ast,json,hashlib,html
ROOT=Path(__file__).parent;SRC=Path('/mnt/data/dealgo_phase19');S=ROOT/'screens';D=ROOT/'docs';A=ROOT/'assets';P=ROOT/'preview'
for x in [S,D,A,P]: x.mkdir(exist_ok=True)
# Reuse the exact approved Phase19.1 primitive stylesheet; don't produce another visual identity.
tree=ast.parse((SRC/'build_phase19.py').read_text(encoding='utf-8'))
css=next(ast.literal_eval(n.value) for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(k,ast.Name) and k.id=='css' for k in n.targets))
css+='''
body{font-size:12.5px}.content{padding:15px 18px 95px}.content .card{margin-bottom:10px;padding:13px}.content .card .title{font-size:15px}.content .item{padding:9px 0}.content .divrow{padding:9px 0}
.stepline{display:flex;align-items:center;justify-content:space-between;gap:4px;margin:4px 0 14px}.step{flex:1;height:6px;background:#e9e4f2;border-radius:8px}.step.done{background:#2bbb6e}.step.cur{background:#7132d6}
.field{margin:9px 0}.field .label{font-weight:750;color:#585d6b;margin-bottom:5px}.field .input{padding:10px 12px}.docbox{border-radius:15px;border:1px dashed #c9b1e9;background:linear-gradient(125deg,#f5f0ff,#fbfff9);padding:14px;text-align:center;flex:1;min-height:100px}.docicon{font-size:32px;margin:8px 0}.docbox .label{font-size:11px}
.reason{display:flex;align-items:flex-start;gap:9px;border-radius:13px;background:#fff5f2;border:1px solid #ffdcd5;padding:10px;margin-top:8px}.reason b{font-size:12px}.reason .label{margin-top:3px}.reason .code{font-size:10px;color:#bb5c53}.reason.good{background:#f0f9f3;border-color:#d5edda}
.privacy{font-size:10.5px;color:#67697c;line-height:1.45}.staterow{display:flex;gap:9px;align-items:center;padding:10px 0;border-bottom:1px solid #f2eff7}.staterow:last-child{border:0}.check{width:23px;height:23px;border-radius:50%;background:#def5e4;display:grid;place-items:center;color:#16a34a;font-weight:900;flex:none}.check.warn{background:#fff0df;color:#d88520}.check.no{background:#ffe9ec;color:#d63151}
.legal{border:1px solid #ded8e9;background:#faf9fd;border-radius:13px;padding:11px;line-height:1.5;font-size:11px}.legal b{display:block;font-size:12px;margin-bottom:4px}.kpi{padding:15px;background:linear-gradient(118deg,#edebff,#effbf3);border:1px solid #e6e0f0;border-radius:18px;margin-bottom:12px}.kpi .title{font-size:16px}.bigicon{font-size:35px;width:67px;height:67px;border-radius:20px;display:grid;place-items:center;background:#eee7ff}.center{text-align:center}.tagmark{position:absolute;top:15px;right:15px;background:#fff6f7;border-radius:9px;font-size:10px;color:#bd6771;padding:5px 7px}.countline{font-weight:850;font-size:18px;color:var(--purple)}
'''
# Same wrapper as Phase19.1: 500x1018 @2x, consistent typography, padding, safe area.
def render(sid,title,content,cta=None,sub=None):
 footer=f'<div class="footer"><div class="btn">{cta} →</div></div>' if cta else ''
 return f'''<!DOCTYPE html><html lang="vi"><head><meta charset="utf-8"><meta name="viewport" content="width=500,initial-scale=1"><title>{sid} · DealGo Phase 19.2</title><style>{css}</style></head><body data-screen="{sid}"><div class="stage"><div class="phone"><div class="status"><div>9:41</div><div class="bars">▂ ▄ ▆ ᴡɪғɪ ▰</div></div><div class="header"><div class="back">‹</div><div class="htext"><h1>{title}</h1>{'<small>'+sub+'</small>' if sub else ''}</div><div class="topaction">Deal<span style="color:#14a13c">Go</span></div></div><div class="viewport"><div class="content">{content}</div>{footer}</div><div class="homepill"></div></div></div></body></html>'''
def write(sid,title,content,cta=None,sub=None):
 (S/(sid+'.html')).write_text(render(sid,title,content,cta,sub),encoding='utf8')
def card(title,inside,kind=''):return f'<section class="card {kind}"><div class="title mb8">{title}</div>{inside}</section>'
def pill(x,kind=''):return f'<span class="pill {kind}">{x}</span>'
def notice(x,kind=''):return f'<div class="notice {kind}">{x}</div>'
def step(n,t):return '<div class="row between"><span class="label">'+t+'</span><b class="purpletext small">Bước '+str(n)+'/5</b></div><div class="stepline">'+''.join(f'<div class="step {"done" if i<n else "cur" if i==n else ""}"></div>' for i in range(1,6))+'</div>'
def item(icon,title,sub='',status='',kind='green'):
 return f'<div class="staterow"><div class="logoicon {"orange" if kind=="orange" else "green" if kind=="green" else ""}">{icon}</div><div class="flex1"><b>{title}</b><div class="label">{sub}</div></div>{pill(status,kind) if status else ""}</div>'
def reason(code,title,sub,good=False):return f'<div class="reason {"good" if good else ""}"><div class="check {"" if good else "no"}">{"✓" if good else "!"}</div><div class="flex1"><b>{title}</b><div class="label">{sub}</div><div class="code">{code}</div></div></div>'
def legal(t,copy):return f'<div class="legal"><b>{t}</b>{copy}</div>'
def control(title,v):return f'<div class="field"><div class="label">{title}</div><div class="input">{v}</div></div>'
BRAND='Bún Bò Huế O Cô';DRIVER='Trần Minh Anh';PLATE='43H1-123.45'
# Merchant KYB, validation before backend approval.
write('M004','Xác minh người đại diện',step(2,'Đăng ký cửa hàng · KYB')+
 card('Giấy tờ định danh',notice('Dữ liệu mẫu đã được che. Không hiển thị số CCCD hay ảnh giấy tờ thực trong thiết kế.')+
 '<div class="row mt12"><div class="docbox"><div class="docicon">▣</div><b>Mặt trước</b><div class="label">Tài liệu minh họa</div>'+pill('Đã tải lên','green')+'</div><div class="docbox"><div class="docicon">▤</div><b>Mặt sau</b><div class="label">Tài liệu minh họa</div>'+pill('Chờ đối chiếu','orange')+'</div></div>')+
 card('Hướng dẫn chụp ảnh',item('◉','Ảnh đầy đủ bốn góc','Không lóa, nhòe, mất chữ', 'Kiểm tra khi gửi')+item('♙','Đúng giấy tờ người đại diện','Người có thẩm quyền pháp lý','Bắt buộc'))+
 notice('Đã tải ảnh lên chưa đồng nghĩa tài khoản được xác minh. Kết quả cuối do dịch vụ KYC/KYB backend trả về.'), 'Tiếp tục')
write('M005','Hồ sơ pháp lý Shop',step(2,'Đăng ký cửa hàng · KYB')+
 card('Thông tin tổ chức',control('Loại hình đăng ký','Hộ kinh doanh')+control('Tên cơ sở kinh doanh',BRAND)+control('Mã số thuế (nếu áp dụng)','••••••••••'))+
 card('Giấy tờ cần cung cấp',item('▤','Tài liệu kinh doanh','Tải lại nếu hết hạn hoặc không hợp lệ','Chờ duyệt','orange')+item('▣','Tài liệu bổ sung','Chỉ yêu cầu theo ngành hàng / loại hình','Theo điều kiện','orange'))+
 notice('Hệ thống quyết định giấy tờ bắt buộc theo ngành hàng, mô hình kinh doanh và quy định hiện hành. Không mặc định mọi Shop đều cần cùng một bộ giấy tờ.'),'Lưu và tiếp tục')
write('M010','Rà soát hồ sơ Shop',step(5,'Kiểm tra trước khi gửi')+
 card('Tình trạng hồ sơ',item('✓','Thông tin cửa hàng',BRAND,'Đủ dữ liệu')+item('✓','Người đại diện','Đã cung cấp giấy tờ','Đủ dữ liệu')+item('✓','Tài liệu kinh doanh','Tải đủ theo danh sách yêu cầu','Đủ dữ liệu')+item('✓','Ngân hàng nhận tiền','Xác nhận thông tin chủ tài khoản','Đủ dữ liệu'))+
 card('Quyền và điều khoản',legal('Tôi đồng ý gửi hồ sơ để xác minh','Bằng cách tiếp tục, tôi cho phép hệ thống xử lý dữ liệu định danh cho mục đích thẩm định. Kết quả được xác nhận sau khi bộ phận duyệt kiểm tra.')+'<div class="row mt8"><span class="check">✓</span><b class="small">Đã đọc, đồng ý với điều khoản phiên bản KYB-v1</b></div>')+
 notice('Gửi hồ sơ tạo một phiên xét duyệt. Mọi thay đổi về giấy tờ sau khi gửi phải tạo lần bổ sung mới.'),'Gửi xét duyệt')
write('M011','Trạng thái xét duyệt Shop',
 '<div class="kpi center"><div class="bigicon" style="margin:0 auto 10px">▤</div><b class="title">Đang thẩm định hồ sơ</b><div class="subtitle mt8">'+BRAND+'</div>'+pill('PENDING_REVIEW','orange')+'</div>'+
 card('Tiến trình kiểm tra',item('✓','Đã tiếp nhận hồ sơ','12/10/2026 · Mã DEMO-SHOP-001','Hoàn thành')+item('◷','Đối chiếu giấy tờ','Đang chờ xác minh hợp lệ','Đang kiểm tra','orange')+item('○','Kích hoạt bán hàng','Chỉ sau khi được phê duyệt','Chưa kích hoạt','orange'))+
 card('Quyền hoạt động hiện tại',item('▣','Quản lý dữ liệu cửa hàng','Có thể chuẩn bị menu, ảnh và giờ mở cửa','Cho phép')+item('⊘','Nhận đơn mới','Chưa bật đến khi Shop được duyệt','Tạm chặn','orange'))+
 notice('Chưa có thời hạn duyệt được bảo đảm. Ứng dụng sẽ cập nhật khi backend thay đổi trạng thái.'),'Theo dõi hồ sơ')
write('M012','Bổ sung hồ sơ Shop',
 notice('Cần bổ sung 2 mục trong hồ sơ để tiếp tục xét duyệt. Dữ liệu bản cũ vẫn giữ làm lịch sử.','amber')+
 card('Lý do cần chỉnh sửa',reason('KYB-DOC-BLUR','Ảnh giấy tờ kinh doanh không rõ','Vui lòng chụp lại đầy đủ các cạnh.')+reason('KYB-ADDR-MISMATCH','Địa chỉ không khớp','Đối chiếu lại địa chỉ Shop với tài liệu.')+
 '<div class="row mt12"><div class="btn outline flex1">Tải ảnh lại</div><div class="btn outline flex1">Sửa địa chỉ</div></div>')+
 card('Kiểm tra trước khi nộp lại',item('✓','Người đại diện','Không cần chụp lại nếu không thay đổi','Giữ nguyên')+item('◷','Giấy tờ kinh doanh','Đang đợi tài liệu thay thế','Cần bổ sung','orange'))+
 notice('Sau khi gửi lại, trạng thái chuyển sang RE_SUBMITTED. Không tự hiển thị “Đã duyệt” chỉ vì upload thành công.'),'Gửi lại hồ sơ')
write('M044','Gia hạn giấy tờ Shop',
 card('Trạng thái pháp lý cửa hàng',f'<div class="row"><div class="logoicon orange">!</div><div class="flex1"><b>{BRAND}</b><div class="label">Một tài liệu đã hết hiệu lực</div></div>{pill("Cần cập nhật","orange")}</div>','warning')+
 card('Giấy tờ cần cập nhật',reason('KYB-DOC-EXPIRED','Giấy tờ kinh doanh hết hạn','Hết hạn 10/10/2026; vui lòng tải bản còn hiệu lực.')+'<div class="btn outline mt12">Tải giấy tờ mới</div>')+
 card('Ảnh hưởng đến hoạt động',item('◷','Nhận đơn / bán hàng','Quyền sẽ tuân theo quyết định hậu kiểm của hệ thống','Hạn chế','orange')+item('✓','Xem lịch sử đơn','Không làm mất dữ liệu giao dịch đã hoàn tất','Cho phép'))+
 notice('Nếu điều kiện pháp lý bắt buộc không còn hiệu lực, backend sẽ chặn các thao tác bị ảnh hưởng đến khi hoàn tất xác minh lại.'),'Gửi cập nhật')
# Driver KYC / per-service capability.
write('D004','Chụp giấy tờ định danh',step(2,'KYC tài xế · Dữ liệu minh họa')+
 card('Tài liệu cần chụp','<div class="docbox" style="min-height:200px;position:relative"><div class="tagmark">DEMO · ĐÃ CHE</div><div style="height:100px;width:205px;border:3px solid #26b768;border-radius:12px;margin:22px auto 12px;background:linear-gradient(125deg,#e8f9ef,#e7eff8);display:grid;place-items:center;font-size:28px">▣</div><b>Mặt trước giấy tờ</b><div class="label">Không hiển thị ảnh thật trong mẫu UI</div></div><div class="row mt12">'+pill('Mặt trước','green')+pill('Mặt sau','gray')+'</div>')+
 card('Hướng dẫn chụp',item('◉','Giấy tờ trong khung','Đủ 4 góc, có ánh sáng','Bắt buộc')+item('⊘','Không dùng ảnh từ màn hình','Tránh ảnh giả, phản chiếu hoặc làm mờ','Bắt buộc'))+
 notice('Hệ thống chỉ bắt đầu kiểm tra sau khi tải đủ hai mặt và gửi hồ sơ. Không lưu giấy tờ vào ảnh công khai của tài xế.'),'Chụp / tải ảnh')
write('D005','Kiểm tra thông tin OCR',step(2,'OCR hỗ trợ nhập liệu; chưa phải duyệt KYC')+
 notice('Đã trích xuất dữ liệu mẫu. Bạn cần kiểm tra lại và chỉnh sửa chỗ sai trước khi nộp.','')+
 card('Dữ liệu đọc từ giấy tờ',control('Họ tên',DRIVER)+control('Ngày sinh','04/06/2003')+control('Số định danh','•••• •••• 901')+control('Địa chỉ cư trú','Đà Nẵng, Việt Nam'))+
 card('Kiểm tra trùng khớp',reason('KYC-OCR-LOWCONF','Trường “nơi cấp” chưa rõ','Cần kiểm tra trên giấy tờ gốc.')+'<div class="row mt12"><div class="btn outline flex1">Sửa nội dung</div><div class="btn outline flex1">Chụp lại</div></div>')+
 notice('OCR là gợi ý kỹ thuật, không thay thế xác minh giấy tờ thật / kiểm tra danh tính.'),'Xác nhận thông tin')
write('D006','Xác minh khuôn mặt',step(3,'Kiểm tra người thật và đối chiếu giấy tờ')+
 card('Xác minh khuôn mặt','<div class="bigicon" style="margin:8px auto 15px;border-radius:50%;height:142px;width:142px;font-size:78px;background:linear-gradient(135deg,#e9dbff,#ddf7e8);border:5px solid #45c780">♙</div><div class="center"><b>Nhìn thẳng vào camera</b><div class="subtitle mt8">Ánh sáng đủ · không che mặt · làm theo hướng dẫn</div></div>')+
 card('Các bước kiểm tra',item('◉','Camera đã được cấp quyền','Chỉ chụp khi bạn bắt đầu xác minh','Sẵn sàng')+item('◷','Kiểm tra liveness','Chưa hoàn tất kiểm tra chống giả mạo','Đang chờ','orange')+item('○','So khớp giấy tờ','Đợi kết quả dịch vụ xác minh','Chưa duyệt','orange'))+
 notice('Ứng dụng không tự đánh dấu “Xác thực thành công” trên ảnh camera. Quyết định cuối cùng do hệ thống trả về.'),'Bắt đầu xác minh')
write('D009','Giấy tờ phương tiện',step(4,'Điều kiện phương tiện theo dịch vụ')+
 card('Phương tiện đang đăng ký',f'<div class="row"><div class="logoicon green">🛵</div><div class="flex1"><b>Honda Vision · {PLATE}</b><div class="label">Xe máy · Phục vụ chở khách / giao món</div></div></div>','purple')+
 card('Tài liệu đang có',item('▤','Giấy đăng ký xe','Ảnh đã tải, chờ đối chiếu','Chờ duyệt','orange')+item('▥','Bảo hiểm xe','Kiểm tra hạn hiệu lực theo quy định áp dụng','Chờ duyệt','orange')+item('◷','Giấy phép lái xe','Điều kiện dịch vụ Chở khách','Cần duyệt','orange'))+
 notice('Quyền chạy xe hoặc giao đồ ăn được xác định riêng. Thiếu một giấy tờ không tự động đồng nghĩa mất mọi quyền nhận việc.'),'Tiếp tục')
write('D012','Rà soát hồ sơ tài xế',step(5,'Kiểm tra trước khi gửi xét duyệt')+
 card('Hồ sơ cá nhân',item('✓','Thông tin tài xế',DRIVER,'Đã nhập')+item('✓','CCCD và khuôn mặt','Đã tải dữ liệu, chờ xác minh','Đã gửi')+item('✓','Giấy phép lái xe','Đã khai báo, chưa có kết luận','Đã gửi'))+
 card('Dịch vụ đăng ký',item('🛵','Chở khách','Cần KYC, giấy phép và xe hợp lệ','Đợi duyệt','orange')+item('🥡','Giao đồ ăn','Điều kiện riêng theo hồ sơ tài xế','Đợi duyệt','orange'))+
 legal('Xác nhận nộp hồ sơ','Tôi xác nhận dữ liệu đã khai báo là chính xác và đồng ý việc xử lý hồ sơ cho mục đích kiểm tra điều kiện tham gia dịch vụ.')+
 notice('Gửi hồ sơ sẽ tạo một bản ghi xét duyệt; các nút Online/Nhận chuyến vẫn bị khóa cho đến khi backend phê duyệt.'),'Gửi hồ sơ')
write('D013','Kết quả xét duyệt KYC',
 '<div class="kpi center"><div class="bigicon" style="margin:0 auto 10px">◴</div><b class="title">Đang thẩm định</b><div class="subtitle mt8">Hồ sơ tài xế '+DRIVER+'</div>'+pill('PENDING_REVIEW','orange')+'</div>'+
 card('Trạng thái theo dịch vụ',item('◷','Chở khách','KYC và điều kiện xe chưa được duyệt','Chưa được nhận','orange')+item('◷','Giao đồ ăn','Đang kiểm tra điều kiện riêng','Chưa được nhận','orange'))+
 card('Tiến trình hồ sơ',item('✓','Đã gửi hồ sơ','12/10/2026 · KYC-DRV-DEMO-01','Hoàn thành')+item('◷','Xác minh giấy tờ','Đang đối chiếu','Đang xử lý','orange')+item('○','Kích hoạt nhận việc','Chỉ khi từng quyền dịch vụ được chấp thuận','Chờ','orange'))+
 notice('Ứng dụng cập nhật kết quả khi backend thay đổi quyền. Không cho phép bật Online nếu chưa đủ điều kiện.',''),'Theo dõi trạng thái')
write('D014','Bổ sung hồ sơ tài xế',
 notice('Hồ sơ yêu cầu chỉnh sửa. Mỗi mục có lý do rõ ràng, không cần gửi lại toàn bộ hồ sơ không thay đổi.','amber')+
 card('Giấy tờ cần sửa',reason('KYC-ID-BLUR','Ảnh CCCD chưa rõ','Chụp lại mặt trước đủ ánh sáng.')+reason('KYC-LICENSE-EXPIRED','Giấy phép không còn hiệu lực','Cần bổ sung giấy phép còn hạn.')+'<div class="row mt12"><div class="btn outline flex1">Chụp lại CCCD</div><div class="btn outline flex1">Cập nhật GPLX</div></div>')+
 card('Giữ nguyên các mục hợp lệ',item('✓','Khuôn mặt','Không yêu cầu quay lại nếu không có thay đổi','Giữ nguyên')+item('✓','Tài khoản ngân hàng','Chưa phát hiện yêu cầu cập nhật','Giữ nguyên'))+
 notice('Gửi lại chuyển hồ sơ sang RE_SUBMITTED. Quyền nhận việc chỉ mở khi việc xác minh mới đã hoàn tất.'),'Gửi bổ sung')
write('D015','Giấy tờ và quyền dịch vụ',
 card('Cảnh báo cần xử lý',f'<div class="row"><div class="logoicon orange">!</div><div class="flex1"><b>GPLX cần cập nhật</b><div class="label">Hết hạn 10/10/2026 · KYC-LICENSE-EXPIRED</div></div>{pill("Đã hết hạn","red")}</div>','warning')+
 card('Quyền nhận chuyến hiện tại',item('⊘','Chở khách – xe máy','Giấy phép chưa đủ điều kiện','Đã khóa','orange')+item('✓','Giao đồ ăn','Vẫn đủ điều kiện theo phiên quyền hiện tại','Được phép'))+
 card('Các bước khôi phục',item('1','Tải GPLX mới','Thông tin rõ, còn hiệu lực','Cần thực hiện','orange')+item('2','Chờ kiểm tra lại','Bật lại đúng dịch vụ sau khi được chấp thuận','Chưa hoàn tất','orange'))+
 notice('Tài xế vẫn có thể xem thu nhập và lịch sử; mọi lệnh nhận cuốc cần backend kiểm tra capability ở thời điểm thao tác.',''),'Cập nhật giấy phép')
write('D040','Hồ sơ và năng lực tài xế',
 card('Thông tin tài xế',f'<div class="row"><div class="avatar">A</div><div class="flex1"><b>{DRIVER}</b><div class="label">Honda Vision · {PLATE}</div>{pill("KYC cá nhân đã xác minh","green")}</div></div>','purple')+
 card('Quyền sử dụng dịch vụ',item('⊘','Chở khách','Chờ xác minh lại giấy phép lái xe','Tạm ngưng','orange')+item('✓','Giao đồ ăn','Có quyền nhận đơn theo hồ sơ hiện tại','Đang cho phép'))+
 card('Tài liệu cần cập nhật',reason('KYC-LICENSE-EXPIRED','GPLX xe máy hết hạn','Bổ sung và đợi kiểm tra lại trước khi nhận chuyến khách.')+'<div class="btn outline mt12">Xem giấy tờ và trạng thái</div>')+
 notice('Tên, giấy tờ định danh và quyền dịch vụ không thay thế bằng nút Sửa hồ sơ thông thường. Mọi thay đổi pháp lý phải được xác minh lại.'),'Xem hồ sơ đã gửi')
write('D041','Đổi phương tiện',
 card('Phương tiện hiện tại',f'<div class="row"><div class="logoicon green">🛵</div><div class="flex1"><b>Honda Vision</b><div class="label">{PLATE} · Đang liên kết</div></div>{pill("Đang dùng","green")}</div>')+
 card('Đăng ký xe thay thế',control('Loại phương tiện','Xe máy')+control('Hãng và mẫu xe','Honda Vision (mẫu)')+control('Biển số mới','43H1-•••.••')+item('▤','Đăng ký xe và bảo hiểm','Cần cung cấp lại nếu thay phương tiện','Yêu cầu','orange'))+
 card('Khi gửi thay đổi',item('◷','Dịch vụ dùng xe mới','Chờ duyệt phương tiện thay thế','Chờ kiểm tra','orange')+item('✓','Dịch vụ đủ điều kiện khác','Tiếp tục nếu backend vẫn cho phép','Theo quyền'))+
 notice('Không được tự thay phương tiện giữa một chuyến đang hoạt động. Đổi xe có thể yêu cầu tái kiểm tra năng lực dịch vụ.'),'Gửi yêu cầu đổi xe')
# Separate state variants are not new routes or part of 165 screens.
write('M011_REJECTED','Hồ sơ Shop bị từ chối',
 '<div class="kpi center" style="background:#fff1f3"><div class="bigicon" style="margin:0 auto 10px;background:#ffe1e6;color:#c73449">×</div><b class="title">Chưa đủ điều kiện kích hoạt</b><div class="subtitle mt8">'+BRAND+'</div>'+pill('REJECTED','red')+'</div>'+
 card('Lý do từ chối',reason('KYB-LEGAL-INVALID','Giấy tờ kinh doanh không hợp lệ','Cần làm rõ thông tin pháp lý. Hướng dẫn hỗ trợ trong chi tiết yêu cầu.')+reason('KYB-ADDR-MISMATCH','Địa chỉ không khớp','Địa chỉ khai báo khác tài liệu.') )+
 notice('Hồ sơ bị từ chối không tự xóa tài khoản; cần mở yêu cầu hỗ trợ hoặc nộp lại theo chính sách.','amber'),'Xem hướng dẫn nộp lại')
write('M012_RESUBMITTED','Đã nộp hồ sơ bổ sung',
 '<div class="kpi center"><div class="bigicon" style="margin:0 auto 10px">✓</div><b class="title">Đã nhận hồ sơ bổ sung</b><div class="subtitle">Đang đợi kiểm tra lại</div>'+pill('RE_SUBMITTED','orange')+'</div>'+
 card('Lịch sử thay đổi',item('✓','Đã tải ảnh giấy tờ thay thế','Bản bổ sung #2 đã được tiếp nhận','Hoàn thành')+item('◷','Đang kiểm tra lần 2','Kết quả sẽ được cập nhật trong hồ sơ','Chưa duyệt','orange'))+
 notice('Không mở tính năng nhận đơn cho đến khi trạng thái Shop trở thành APPROVED.','amber'),'Về trạng thái hồ sơ')
write('D015_BLOCKED','Quyền chở khách bị giới hạn',
 '<div class="kpi center" style="background:#fff1f3"><div class="bigicon" style="margin:0 auto 10px;background:#ffe1e6;color:#c73449">⊘</div><b class="title">Không thể nhận chuyến chở khách</b><div class="subtitle">Giấy phép lái xe đã hết hiệu lực</div>'+pill('RIDE_SUSPENDED','red')+'</div>'+
 card('Trạng thái nhận việc',item('⊘','Chở khách','Tắt theo quyết định điều kiện dịch vụ','Đã khóa','orange')+item('✓','Giao đồ ăn','Vẫn hợp lệ trong phiên demo này','Có thể nhận'))+
 card('Hành động khôi phục',reason('KYC-LICENSE-EXPIRED','Cần tải giấy phép mới','Không được nhận cuốc Ride khi đang chờ duyệt.')+'<div class="btn outline mt12">Tải ảnh giấy phép mới</div>')+
 notice('Đây là khóa quyền theo loại dịch vụ, không phải xóa tài khoản hoặc khóa mọi giao dịch khác.','amber'),'Mở hồ sơ tài xế')
write('D015_RESTORED','Quyền tài xế đã khôi phục',
 '<div class="kpi center" style="background:#eafaf0"><div class="bigicon" style="margin:0 auto 10px;background:#d3f4dc;color:#16a34a">✓</div><b class="title">Đã đủ điều kiện nhận chuyến</b><div class="subtitle">Giấy phép lái xe mới đã được duyệt</div>'+pill('RIDE_APPROVED','green')+'</div>'+
 card('Quyền dịch vụ hiện tại',item('✓','Chở khách','Đã xác minh giấy phép và xe','Được phép')+item('✓','Giao đồ ăn','Đã đủ điều kiện hiện tại','Được phép'))+
 notice('Online là lựa chọn của tài xế; quyền đủ điều kiện không tự bật ca làm. Hệ thống vẫn kiểm tra lại trước khi ghép việc.'),'Về Dashboard tài xế')
manifest=[{'id':p.stem,'category':('merchant' if p.stem.startswith('M') else 'driver'),'replacement':('_' not in p.stem),'name':p.name} for p in sorted(S.glob('*.html'))]
(D/'patch_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
print('Generated',len(manifest),'HTMLs, replacements:',sum(i['replacement'] for i in manifest))
