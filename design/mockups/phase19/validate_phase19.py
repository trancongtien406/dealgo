from pathlib import Path
import json,hashlib,csv
ROOT=Path(__file__).parent
D=ROOT/'docs';S=ROOT/'screens'
f=json.loads((D/'golden_fixtures.json').read_text())
r=f['ride_car'];b=f['ride_bike'];o=f['food']
assert r['fareOpening']+r['fareDistance']+r['fees']-r['discount']==r['acceptedQuoteAmount']==r['payable']==42000
assert r['service']=='CAR_4' and 'Toyota' in r['vehicle'] and r['plate'].startswith('43A')
assert b['service']=='BIKE' and 'Honda Vision' in b['vehicle'] and b['acceptedQuoteAmount']==45000 and b['plate']!=r['plate']
assert sum(x['qty']*x['price'] for x in o['items'])==o['subtotal']==125000
assert o['subtotal']+o['deliveryFee']-o['discount']==o['payable']==150000
assert o['merchantNet']+o['platformDeliveryFee']+o['driverEarnings']==o['payable']
assert o['driverCashToReconcile']==o['payable']-o['driverEarnings']
assert o['paymentState']=='COD_NOT_YET_COLLECTED'
assert len(list(S.glob('*.png')))==16 and len(list(S.glob('*.html')))==16
for x in 'C004 C005 C006 C007 C008 C009 C010 C011'.split():
 txt=(S/(x+'.html')).read_text()
 assert '42.000đ' in txt,(x,'price missing')
 assert '63.000đ' not in txt and '72.000đ' not in txt and '108.000đ' not in txt
for x in ('C008','C009','C011'):
 txt=(S/(x+'.html')).read_text()
 assert r['driver'] in txt and r['plate'] in txt and r['vehicle'] in txt
for x in ('C028','M016','D030','D036','M035'):
 txt=(S/(x+'.html')).read_text()
 assert o['orderId'] in txt and '150.000đ' in txt
for x in ('M016','D030','D036','M035'):
 txt=(S/(x+'.html')).read_text();assert '125.000đ' in txt
assert '20.000đ' in (S/'D030.html').read_text()
assert '130.000đ' in (S/'D036.html').read_text()
assert 'Tiền COD giữ hộ' in (S/'D036.html').read_text()
meas=json.loads((D/'layout_measurements.json').read_text())
for m in meas:
 assert m['scrollHeight']<=m['clientHeight']+1,('overflow',m['id'],m)
 assert m['bodyScroll']<=500,('horizontal overflow',m['id'])
 assert m['footerTop'] is None or m['lastBottom']<=m['footerTop']-10,('cta overlap',m['id'],m['lastBottom'],m['footerTop'])
expected=[f'{s}{i:03d}' for s,nums in [('S',range(1,29)),('C',range(1,49)),('M',range(1,45)),('D',range(1,46))] for i in nums]
assert len(expected)==165 and len(set(expected))==165
print('PASS: 16 PNG + 16 HTML; pricing, COD, cross-role consistency, responsive frame, 165-ID integrity')
