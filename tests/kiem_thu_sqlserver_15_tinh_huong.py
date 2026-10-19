# -*- coding: utf-8 -*-
"""V4 + V5 unified SQL Server integration tests. ONLY disposable SQL test instance.
Set SQLSERVER_HOST/USER/PASSWORD (e.g. localhost,14331 test container).
This script creates and DROPS ONLY a newly generated random DB; never changes V4.
Needs `pip install pyodbc` + ODBC Driver 18. ODBC fix: all cursors are fully drained and closed before the next command.
Team-reported run: 15/15 PASS on Microsoft SQL Server 2022 (2026-10-19).
"""
from __future__ import annotations
import os,sys,re,uuid,time
from pathlib import Path
from datetime import datetime, timedelta, timezone
from concurrent.futures import ThreadPoolExecutor
try: import pyodbc
except ImportError: sys.exit('pip install pyodbc')
SRC=Path(__file__).resolve().parents[1]/'database/01_cinema_management_schema_v4.sql'
DB='CinemaV5_TEST_'+uuid.uuid4().hex[:12]
HOST=os.getenv('SQLSERVER_HOST','')
USER=os.getenv('SQLSERVER_USER','')
PWD=os.getenv('SQLSERVER_PASSWORD','')
DRIVER=os.getenv('SQLSERVER_DRIVER','ODBC Driver 18 for SQL Server')
if not (HOST and USER and PWD): sys.exit('Thiếu SQLSERVER_HOST/USER/PASSWORD')
# Avoid accidentally running on legacy ports 1433/14330 or an unknown host.
if HOST.lower().replace('127.0.0.1','localhost') != 'localhost,14331':
 sys.exit('Chỉ chạy trên container test localhost,14331. HOST hiện tại: '+HOST)

def conn(db='master',autocommit=True):
 return pyodbc.connect(f'DRIVER={{{DRIVER}}};SERVER={HOST};DATABASE={db};UID={USER};PWD={PWD};'
                       'Encrypt=yes;TrustServerCertificate=yes;Connection Timeout=10;',timeout=30,autocommit=autocommit)

def query(c, sql, args=()):
    """Chạy lệnh không cần trả dữ liệu; tiêu thụ hết kết quả ODBC."""
    cur = c.cursor()
    try:
        cur.execute(sql, *args)
        while True:
            if cur.description is not None:
                cur.fetchall()
            if not cur.nextset():
                break
    finally:
        cur.close()


def value(c, sql, args=()):
    """Lấy ô đầu tiên, đóng hết result sets kể cả INSERT ... OUTPUT."""
    cur = c.cursor()
    try:
        cur.execute(sql, *args)
        row = cur.fetchone()
        if cur.description is not None:
            cur.fetchall()
        while cur.nextset():
            if cur.description is not None:
                cur.fetchall()
        return row[0] if row is not None else None
    finally:
        cur.close()

def insert(c,t,pk,cols,vals):
 return int(value(c,f'INSERT INTO dbo.{t}({cols}) OUTPUT inserted.{pk} VALUES('+','.join('?' for _ in vals)+')',vals))

def proc(name, *args):
    """Mỗi stored procedure có kết nối/cursor riêng, đọc hết result sets."""
    c = conn(DB)
    try:
        cur = c.cursor()
        try:
            cur.execute('EXEC dbo.' + name + ' ' + ','.join('?' for _ in args), *args)
            result = None
            while True:
                if cur.description is not None:
                    row = cur.fetchone()
                    if result is None and row is not None:
                        result = list(row)
                    cur.fetchall()
                if not cur.nextset():
                    break
            return True, result
        finally:
            cur.close()
    except Exception as e:
        return False, str(e)[:450]
    finally:
        c.close()

def install(c):
 text=SRC.read_text(encoding='utf-8-sig').replace('CinemaManagementV5_DualChannel',DB)
 for i,batch in enumerate(re.split(r'(?im)^\s*GO\s*(?:--[^\n]*)?$',text),1):
  if batch.strip():
   try:query(c,batch)
   except Exception as e:raise RuntimeError(f'Schema batch {i} FAILED:\n{batch[:250]}\n{e}') from e

class F:
 def __init__(self,c):
  self.c=c; self.n=0
  self.cx=insert(c,'cinemas','cinema_id','cinema_name,[address],[status]',('Cinema X','Test','ACTIVE'))
  self.cy=insert(c,'cinemas','cinema_id','cinema_name,[address],[status]',('Cinema Y','Test','ACTIVE'))
  def uid(role,cinema,username):
   return insert(c,'[users]','user_id','role_id,cinema_id,username,full_name,password_hash,[status]',
      (value(c,'SELECT role_id FROM dbo.roles WHERE role_code=?',(role,)),cinema,username,username,'TEST_HASH','ACTIVE'))
  self.c1=uid('CASHIER',self.cy,'c1');self.c2=uid('CASHIER',self.cy,'c2')
  self.foreign=uid('CASHIER',self.cx,'cx');self.manager=uid('MANAGER',self.cy,'mgr')
  self.customer=uid('CUSTOMER',None,'customer');self.customer2=uid('CUSTOMER',None,'customer2')
  self.movie=insert(c,'movies','movie_id','title,duration_minutes,age_rating,[status]',('Film Test',100,'P','PUBLISHED'))
  ty=insert(c,'seat_types','seat_type_id','type_name,price_surcharge',('STD',0))
  self.room=insert(c,'rooms','room_id','cinema_id,room_name',[self.cy,'RoomY'])
  self.seats=[insert(c,'seats','seat_id','room_id,seat_type_id,row_label,seat_number,is_active',(self.room,ty,'A',n,1)) for n in (5,6)]
 def show(self):
  self.n+=1
  begin=datetime.now(timezone.utc)+timedelta(days=30+self.n)
  begin=begin.replace(hour=11,minute=0,second=0,microsecond=0)
  end=begin+timedelta(hours=2)
  sid=insert(self.c,'showtimes','showtime_id','movie_id,room_id,starts_at,ends_at,base_price,[status],created_by',
       (self.movie,self.room,begin.isoformat(),end.isoformat(),100000,'PUBLISHED',self.manager))
  slots=[insert(self.c,'showtime_seats','showtime_seat_id','showtime_id,seat_id',(sid,seat)) for seat in self.seats]
  return sid,*slots
 def sale(self,show,who,channel='COUNTER',choice='COUNTER_CASH'):
  r=proc('usp_create_sale',show,who,channel,choice,uuid.uuid4().hex)
  assert r[0],r[1]
  return int(r[1][0]), r[1][2]
 def hold(self,sale,seat,who):
  return proc('usp_hold_seats',sale,str(seat),who) # @hold_minutes defaults NULL
 def attempt(self,sale,who):
  code=uuid.uuid4().hex
  res=proc('usp_create_gateway_attempt',sale,who,code)
  return code,res
 def event(self,code,result='SUCCESS',amount=100000,event_id=None):
  return proc('usp_accept_verified_gateway_event',event_id or uuid.uuid4().hex,code,result,amount,1)

SCORES=[]
def check(name,cond,detail):
 ok=bool(cond); SCORES.append(ok)
 print(f'[{"PASS" if ok else "FAIL"}] {len(SCORES):02d}. {name}: {detail}',flush=True)

def run(c,f):
 # 1. Concurrent counter holds.
 show,a5,a6=f.show();s1,_=f.sale(show,f.c1);s2,_=f.sale(show,f.c2)
 with ThreadPoolExecutor(max_workers=2) as e:
  aa=e.submit(f.hold,s1,a5,f.c1);bb=e.submit(f.hold,s2,a5,f.c2);ra,rb=aa.result(),bb.result()
 held=value(c,'SELECT held_sale_id FROM dbo.showtime_seats WHERE showtime_seat_id=?',(a5,))
 check('Hai quầy cùng giữ A5',sum([ra[0],rb[0]])==1 and held in (s1,s2),(ra[0],rb[0],held))

 # 2. Sold seat must rollback partial hold.
 show,a5,a6=f.show();old,_=f.sale(show,f.c1);assert f.hold(old,a6,f.c1)[0]
 assert proc('usp_confirm_sale_and_issue_tickets',old,'CASH',f.c1)[0]
 new,_=f.sale(show,f.c2);result=proc('usp_hold_seats',new,f'{a5},{a6}',f.c2)
 check('Ghế đã bán không được giữ lẻ',not result[0] and value(c,'SELECT held_sale_id FROM dbo.showtime_seats WHERE showtime_seat_id=?',(a5,)) is None,result[1])

 # 3. Online 5min, online counter 30min, counter 5min.
 show,a5,a6=f.show();online,_=f.sale(show,f.customer,'ONLINE','ONLINE_GATEWAY'); assert f.hold(online,a5,f.customer)[0]
 dur=value(c,'SELECT DATEDIFF(MINUTE,created_at,hold_expires_at) FROM dbo.sales WHERE sale_id=?',(online,))
 counteronline,pickup=f.sale(show,f.customer2,'ONLINE','COUNTER_CASH');assert f.hold(counteronline,a6,f.customer2)[0]
 expiry=value(c,'SELECT hold_expires_at FROM dbo.sales WHERE sale_id=?',(counteronline,))
 check('Hạn giữ theo kênh',dur in (4,5,6) and pickup and len(pickup)==32 and expiry is not None,(dur,pickup is not None))

 # 4. Customer cannot create counter sale; foreign cashier cannot create sale in cinema Y.
 r1=proc('usp_create_sale',show,f.customer,'COUNTER','COUNTER_CASH',uuid.uuid4().hex)
 r2=proc('usp_create_sale',show,f.foreign,'COUNTER','COUNTER_CASH',uuid.uuid4().hex)
 check('Từ chối tạo đơn sai quyền/rạp',not r1[0] and not r2[0],(r1[0],r2[0]))

 # 5. Pickup authorization before payment.
 wrong=proc('usp_confirm_sale_and_issue_tickets',counteronline,'CASH',f.c1,'wrong')
 good=proc('usp_confirm_sale_and_issue_tickets',counteronline,'CASH',f.c1,pickup)
 check('Online trả tại quầy cần mã nhận đơn',not wrong[0] and good[0] and value(c,'SELECT [status] FROM dbo.sales WHERE sale_id=?',(counteronline,))=='PAID',(wrong[0],good[0]))

 # 6. Successful gateway issuance, amount correct.
 attempt,ar=f.attempt(online,f.customer)
 ok=f.event(attempt,'SUCCESS',100000,'good-event-1')
 n=value(c,'SELECT COUNT(*) FROM dbo.tickets WHERE sale_id=?',(online,))
 check('Cổng thanh toán thành công',ar[0] and ok[0] and ok[1][0]=='PROCESSED' and n==1,(ar[0],ok,n))

 # 7. Replay same event_id.
 same=f.event(attempt,'SUCCESS',100000,'good-event-1')
 n=value(c,'SELECT COUNT(*) FROM dbo.tickets WHERE sale_id=?',(online,))
 check('Callback trùng mã sự kiện',same[0] and same[1][0]=='DUPLICATE' and n==1,(same,n))

 # 8. Replayed success new ID must not overwrite successful attempt.
 again=f.event(attempt,'SUCCESS',100000,'good-event-2')
 state=value(c,'SELECT [status] FROM dbo.payment_attempts WHERE attempt_code=?',(attempt,))
 check('SUCCESS lặp mã mới giữ trạng thái SUCCESS',again[0] and again[1][0]=='ALREADY_PAID' and state=='SUCCESS', (again,state))

 # 9. FAILED event followed by SUCCESS new id -> REVIEW_REQUIRED, no tickets.
 show,a5,a6=f.show();s,_=f.sale(show,f.customer,'ONLINE','ONLINE_GATEWAY');assert f.hold(s,a5,f.customer)[0]
 code,ar=f.attempt(s,f.customer);failed=f.event(code,'FAILED',0);late=f.event(code,'SUCCESS',100000)
 state=value(c,'SELECT [status] FROM dbo.sales WHERE sale_id=?',(s,));n=value(c,'SELECT COUNT(*) FROM dbo.tickets WHERE sale_id=?',(s,))
 check('FAILED rồi SUCCESS yêu cầu đối soát',failed[0] and late[0] and state=='REVIEW_REQUIRED' and n==0,(failed,late,state,n))

 # 10. Expired attempt: success recorded for reconciliation, not issued.
 show,a5,a6=f.show();s,_=f.sale(show,f.customer,'ONLINE','ONLINE_GATEWAY');assert f.hold(s,a5,f.customer)[0]
 code,ar=f.attempt(s,f.customer)
 query(c,'UPDATE dbo.sales SET hold_expires_at=DATEADD(SECOND,-1,SYSUTCDATETIME()) WHERE sale_id=?',(s,))
 expired=f.event(code,'SUCCESS',100000)
 state=value(c,'SELECT [status] FROM dbo.sales WHERE sale_id=?',(s,));n=value(c,'SELECT COUNT(*) FROM dbo.tickets WHERE sale_id=?',(s,))
 check('Tiền online đến sau hạn -> đối soát',expired[0] and expired[1][0]=='REVIEW_REQUIRED' and state=='REVIEW_REQUIRED' and n==0,(expired,state,n))

 # 11. Concurrent active payment attempts blocked, old attempt remains CREATED.
 show,a5,a6=f.show();s,_=f.sale(show,f.customer,'ONLINE','ONLINE_GATEWAY');assert f.hold(s,a5,f.customer)[0]
 code,ar=f.attempt(s,f.customer)
 code2,ar2=f.attempt(s,f.customer)
 active=value(c,"SELECT COUNT(*) FROM dbo.payment_attempts WHERE sale_id=? AND [status]='CREATED'",(s,))
 check('Một attempt hoạt động mỗi đơn',ar[0] and not ar2[0] and active==1,(ar[0],ar2[0],active))

 # 12. Cross-showtime booking_seats must be rejected at FK level.
 other,otherA5,_=f.show()
 try:
  query(c,'INSERT INTO dbo.booking_seats(sale_id,showtime_seat_id,showtime_id,quoted_price) VALUES(?,?,?,?)',
    (s,otherA5,other,100000));cross=True
 except pyodbc.Error:cross=False
 check('FK tổng hợp không cho ghế khác suất/đơn',not cross,cross)

 # 13. Hold policy may not be overridden by client.
 show,a5,a6=f.show();s,_=f.sale(show,f.customer,'ONLINE','ONLINE_GATEWAY')
 override=proc('usp_hold_seats',s,str(a5),f.customer,120)
 check('Chặn tự nâng hạn giữ 120 phút',not override[0],override[0])

 # 14. Wrong gateway amount must become REVIEW_REQUIRED, no ticket.
 assert f.hold(s,a5,f.customer)[0];code,ar=f.attempt(s,f.customer)
 wrong=f.event(code,'SUCCESS',123)
 count=value(c,'SELECT COUNT(*) FROM dbo.tickets WHERE sale_id=?',(s,))
 check('Sai số tiền -> cần đối soát',wrong[0] and wrong[1][0]=='REVIEW_REQUIRED' and count==0,(wrong,count))

 # 15. Double confirm should issue one receipt and tickets.
 show,a5,a6=f.show();s,_=f.sale(show,f.c1);assert f.hold(s,a5,f.c1)[0]
 with ThreadPoolExecutor(max_workers=2) as e:
  ra=e.submit(proc,'usp_confirm_sale_and_issue_tickets',s,'CASH',f.c1)
  rb=e.submit(proc,'usp_confirm_sale_and_issue_tickets',s,'CASH',f.c1)
  qa,qb=ra.result(),rb.result()
 n=value(c,'SELECT COUNT(*) FROM dbo.tickets WHERE sale_id=?',(s,))
 check('Xác nhận tiền tại quầy hai lần',sum([qa[0],qb[0]])==1 and n==1,(qa[0],qb[0],n))

 print(f'RESULT: {sum(SCORES)}/{len(SCORES)} PASS on Microsoft SQL Server 2022',flush=True)
 return all(SCORES)

def main():
 admin=conn('master');created=False
 try:
  print('CHỈ MÔI TRƯỜNG TEST:',HOST,'DB:',DB,flush=True)
  query(admin,f'CREATE DATABASE [{DB}]');created=True
  c=conn(DB)
  try:
   install(c)
   print('Cài schema thành công.',flush=True)
   print('Đang tạo dữ liệu mẫu...',flush=True)
   fixture=F(c)
   print('Đã tạo dữ liệu mẫu. Bắt đầu 15 bài kiểm thử.',flush=True)
   result=run(c,fixture)
  finally:c.close()
 finally:
  if created:
   try:
    query(admin,f'ALTER DATABASE [{DB}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE')
    query(admin,f'DROP DATABASE [{DB}]')
    print('Đã xóa database test:',DB,flush=True)
   except Exception as e:print('CẢNH BÁO: database test có thể còn:',DB,str(e)[:200],flush=True)
  admin.close()
 return 0 if result else 1

if __name__=='__main__':
 try:sys.exit(main())
 except Exception as e:print('LỖI TEST/SQL:',str(e)[:2200],flush=True);sys.exit(2)