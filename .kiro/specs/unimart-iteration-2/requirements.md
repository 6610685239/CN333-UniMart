# เอกสารข้อกำหนด (Requirements Document) — UniMart Iteration 2

## บทนำ

UniMart Iteration 2 คือการพัฒนาต่อยอดจาก Iteration 1 ของแพลตฟอร์มตลาดซื้อขายแบบ Closed-Loop สำหรับนักศึกษามหาวิทยาลัยธรรมศาสตร์ โดยเพิ่มฟีเจอร์หลัก 5 ส่วน ได้แก่ ระบบแชทในแอป (Safe Deal), ระบบรีวิวและเครดิตผู้ใช้, ระบบกรองอัจฉริยะ (Smart Filter), การยืนยันตัวตนเฉพาะนักศึกษา TU, และระบบแจ้งเตือน เพื่อเพิ่มความปลอดภัย ความน่าเชื่อถือ และความสะดวกในการใช้งาน

## อภิธานศัพท์ (Glossary)

- **UniMart_System**: ระบบแอปพลิเคชัน UniMart ทั้ง Frontend (Flutter) และ Backend (Node.js/Express)
- **Chat_Service**: บริการแชทแบบ Real-time ภายในแอป UniMart สำหรับการสื่อสารระหว่างผู้ซื้อและผู้ขาย
- **Chat_Room**: ห้องสนทนาระหว่างผู้ใช้ 2 คนที่เชื่อมโยงกับสินค้าเฉพาะรายการ
- **Message**: ข้อความที่ส่งภายใน Chat_Room ประกอบด้วยข้อความตัวอักษรหรือรูปภาพ
- **Review_System**: ระบบรีวิวและให้คะแนนดาวหลังทำธุรกรรมเสร็จสิ้น
- **Review**: ข้อมูลรีวิวประกอบด้วยคะแนนดาว (1-5) และข้อความรีวิว
- **Credit_Score**: คะแนนเฉลี่ยจากรีวิวทั้งหมดของผู้ใช้ ใช้วัดความน่าเชื่อถือ
- **Smart_Filter**: ระบบกรองสินค้าตามเงื่อนไขเฉพาะ เช่น คณะ, โซนหอพัก, จุดนัดพบ
- **Auth_Service**: บริการยืนยันตัวตนผู้ใช้ผ่าน TU API (restapi.tu.ac.th/api/v1/auth/Ad/verify) โดยใช้รหัสนักศึกษาและรหัสผ่านระบบ reg.tu.ac.th
- **TU_API**: REST API ของมหาวิทยาลัยธรรมศาสตร์ สำหรับยืนยันตัวตนนักศึกษาและบุคลากร (POST https://restapi.tu.ac.th/api/v1/auth/Ad/verify) ส่งคืนข้อมูล username, displayname_th/en, email, faculty, department, type (student/employee), tu_status, statusid
- **Notification_Service**: บริการแจ้งเตือนแบบ Real-time สำหรับข้อความแชทและสถานะธุรกรรม
- **Buyer**: ผู้ใช้ที่ต้องการซื้อหรือเช่าสินค้า
- **Seller**: ผู้ใช้ที่ลงขายหรือให้เช่าสินค้า
- **Transaction**: ธุรกรรมการซื้อขายหรือเช่าสินค้าระหว่าง Buyer และ Seller
- **Report**: การรายงานพฤติกรรมไม่เหมาะสมของผู้ใช้ภายในระบบแชท
- **Meeting_Point**: จุดนัดพบที่แนะนำภายในมหาวิทยาลัยธรรมศาสตร์ เช่น โรงอาหารกรีน, SC Hall, ป้ายรถตู้
- **Dormitory_Zone**: โซนหอพักภายในมหาวิทยาลัย เช่น เชียงราก, อินเตอร์โซน, ในมหาวิทยาลัย

## ข้อกำหนด (Requirements)

---

### ข้อกำหนดที่ 1: ระบบแชทในแอป (In-App Chat — Safe Deal)

**User Story:** ในฐานะนักศึกษาที่ใช้ UniMart ฉันต้องการแชทกับผู้ซื้อ/ผู้ขายภายในแอปได้โดยตรง เพื่อที่จะไม่ต้องแชร์ข้อมูลส่วนตัว (Line/เบอร์โทร) และมีหลักฐานการสนทนาเก็บไว้

#### เกณฑ์การยอมรับ (Acceptance Criteria)

1. WHEN Buyer กดปุ่ม "แชท" ในหน้ารายละเอียดสินค้า, THE Chat_Service SHALL สร้าง Chat_Room ใหม่ที่เชื่อมโยง Buyer, Seller, และ Product หรือเปิด Chat_Room ที่มีอยู่แล้วหากเคยสร้างไว้
2. WHEN ผู้ใช้ส่ง Message ใน Chat_Room, THE Chat_Service SHALL จัดส่ง Message ไปยังผู้รับภายใน 2 วินาที แบบ Real-time
3. THE Chat_Service SHALL แสดง Message ทั้งหมดใน Chat_Room เรียงตามลำดับเวลาจากเก่าไปใหม่
4. WHEN ผู้ใช้เปิดหน้ารายการแชท, THE Chat_Service SHALL แสดงรายการ Chat_Room ทั้งหมดของผู้ใช้ พร้อมชื่อคู่สนทนา, ข้อความล่าสุด, เวลา, และจำนวนข้อความที่ยังไม่ได้อ่าน
5. WHEN ผู้ใช้ส่งรูปภาพใน Chat_Room, THE Chat_Service SHALL อัปโหลดรูปภาพและแสดงรูปภาพใน Chat_Room ภายใน 5 วินาที
6. THE Chat_Service SHALL เก็บประวัติ Message ทั้งหมดใน Chat_Room ไว้ตลอดอายุการใช้งานของ Chat_Room เพื่อใช้เป็นหลักฐานกรณีเกิดข้อพิพาท
7. WHEN ผู้ใช้กดปุ่ม "รายงาน" ใน Chat_Room, THE Chat_Service SHALL บันทึก Report ที่ประกอบด้วย Chat_Room ID, ผู้รายงาน, ผู้ถูกรายงาน, เหตุผล, และ timestamp
8. IF ผู้ใช้ส่ง Message ขณะที่การเชื่อมต่อเครือข่ายขาดหาย, THEN THE Chat_Service SHALL แสดงสถานะ "ส่งไม่สำเร็จ" และให้ผู้ใช้สามารถกดส่งซ้ำได้

---

### ข้อกำหนดที่ 2: ระบบรีวิวและเครดิตผู้ใช้ (User Credit/Review System)

**User Story:** ในฐานะนักศึกษาที่ใช้ UniMart ฉันต้องการดูรีวิวและคะแนนของผู้ขาย/ผู้ซื้อ เพื่อที่จะตัดสินใจได้ว่าคู่ค้าน่าเชื่อถือหรือไม่

#### เกณฑ์การยอมรับ (Acceptance Criteria)

1. WHEN Transaction เสร็จสิ้น, THE Review_System SHALL อนุญาตให้ Buyer เขียน Review ที่ประกอบด้วยคะแนนดาว (1-5) และข้อความรีวิว สำหรับ Seller
2. WHEN Transaction เสร็จสิ้น, THE Review_System SHALL อนุญาตให้ Seller เขียน Review ที่ประกอบด้วยคะแนนดาว (1-5) และข้อความรีวิว สำหรับ Buyer
3. THE Review_System SHALL คำนวณ Credit_Score ของผู้ใช้จากค่าเฉลี่ยคะแนนดาวของ Review ทั้งหมดที่ได้รับ
4. WHEN ผู้ใช้เปิดหน้าโปรไฟล์ของผู้ใช้คนอื่น, THE Review_System SHALL แสดง Credit_Score, จำนวน Review ทั้งหมด, และรายการ Review ล่าสุด
5. WHEN ผู้ใช้กรองสินค้าตามความน่าเชื่อถือ, THE Review_System SHALL กรองแสดงเฉพาะสินค้าจาก Seller ที่มี Credit_Score ตั้งแต่ค่าที่ผู้ใช้กำหนดขึ้นไป
6. IF ผู้ใช้พยายามเขียน Review สำหรับ Transaction ที่เขียน Review ไปแล้ว, THEN THE Review_System SHALL แสดงข้อความแจ้งว่า "คุณได้รีวิวธุรกรรมนี้แล้ว" และปฏิเสธการบันทึก Review ซ้ำ
7. IF ผู้ใช้ส่ง Review ที่มีคะแนนดาวไม่อยู่ในช่วง 1-5, THEN THE Review_System SHALL แสดงข้อความแจ้งเตือนและปฏิเสธการบันทึก Review

---

### ข้อกำหนดที่ 3: ระบบกรองอัจฉริยะ (Smart Filter System)

**User Story:** ในฐานะนักศึกษาที่ใช้ UniMart ฉันต้องการกรองสินค้าตามคณะ, โซนหอพัก, และจุดนัดพบ เพื่อที่จะหาสินค้าที่เกี่ยวข้องและสะดวกในการรับสินค้าได้รวดเร็ว

#### เกณฑ์การยอมรับ (Acceptance Criteria)

1. WHEN ผู้ใช้เลือกกรองสินค้าตามคณะ, THE Smart_Filter SHALL แสดงเฉพาะสินค้าที่ Seller สังกัดคณะที่เลือก
2. WHEN ผู้ใช้เลือกกรองสินค้าตาม Dormitory_Zone, THE Smart_Filter SHALL แสดงเฉพาะสินค้าที่มี location ตรงกับ Dormitory_Zone ที่เลือก (เชียงราก, อินเตอร์โซน, ในมหาวิทยาลัย)
3. WHEN ผู้ใช้เลือกกรองสินค้าตาม Meeting_Point, THE Smart_Filter SHALL แสดงเฉพาะสินค้าที่มี Meeting_Point ตรงกับจุดนัดพบที่เลือก (โรงอาหารกรีน, SC Hall, ป้ายรถตู้)
4. WHEN ผู้ใช้เลือกเงื่อนไขกรองหลายรายการพร้อมกัน, THE Smart_Filter SHALL แสดงเฉพาะสินค้าที่ตรงกับเงื่อนไขทุกรายการที่เลือก (AND logic)
5. WHEN ผู้ใช้กดปุ่ม "ล้างตัวกรอง", THE Smart_Filter SHALL รีเซ็ตเงื่อนไขกรองทั้งหมดและแสดงสินค้าทั้งหมด
6. THE Smart_Filter SHALL แสดงจำนวนสินค้าที่ตรงกับเงื่อนไขกรองปัจจุบัน
7. WHEN ผู้ใช้ลงขายสินค้า, THE UniMart_System SHALL ให้ผู้ใช้เลือก Meeting_Point จากรายการจุดนัดพบที่กำหนดไว้

---

### ข้อกำหนดที่ 4: การยืนยันตัวตนเฉพาะนักศึกษา TU (Enhanced Authentication)

**User Story:** ในฐานะผู้ดูแลระบบ UniMart ฉันต้องการให้เฉพาะนักศึกษาและบุคลากรมหาวิทยาลัยธรรมศาสตร์เท่านั้นที่สามารถลงทะเบียนใช้งานได้ เพื่อรักษาความปลอดภัยของชุมชน

**TU API Reference:**
- Endpoint: `POST https://restapi.tu.ac.th/api/v1/auth/Ad/verify`
- Headers: `Content-Type: application/json`, `Application-Key: <access_token>`
- Request Body: `{ "UserName": "<รหัสนักศึกษา>", "PassWord": "<รหัสผ่าน reg.tu.ac.th>" }`
- Response (Student): `{ status, message, type, username, tu_status, statusid, displayname_th, displayname_en, email, department, faculty }`
- Response (Employee): `{ status, message, type, username, displayname_th, displayname_en, StatusWork, StatusEmp, email, department, organization }`
- Rate Limit: 1,000 requests/hour/key

#### เกณฑ์การยอมรับ (Acceptance Criteria)

1. WHEN ผู้ใช้กรอกรหัสนักศึกษา (username) และรหัสผ่าน (password) ในหน้าลงทะเบียน, THE Auth_Service SHALL ส่งข้อมูลไปยัง TU API (`POST https://restapi.tu.ac.th/api/v1/auth/Ad/verify`) พร้อม Application-Key เพื่อยืนยันตัวตน
2. WHEN TU API ตอบกลับด้วย `status: true`, THE Auth_Service SHALL สร้างบัญชีผู้ใช้ในระบบ UniMart โดยบันทึกข้อมูลจาก TU API ได้แก่ username (รหัสนักศึกษา), displayname_th, displayname_en, email (@dome.tu.ac.th), faculty, department, type (student/employee), tu_status, และ statusid
3. IF TU API ตอบกลับด้วย `status: false`, THEN THE Auth_Service SHALL แสดงข้อความแจ้งเตือน "รหัสนักศึกษาหรือรหัสผ่านไม่ถูกต้อง กรุณาใช้รหัสเดียวกับระบบ reg.tu.ac.th" และปฏิเสธการลงทะเบียน
4. IF ผู้ใช้ที่ยืนยันตัวตนสำเร็จมี tu_status ไม่ใช่ "ปกติ" (เช่น พักการศึกษา, ลาออก, สำเร็จการศึกษา), THEN THE Auth_Service SHALL แสดงข้อความแจ้งเตือนสถานะปัจจุบันของผู้ใช้ แต่ยังอนุญาตให้ลงทะเบียนได้
5. WHEN ผู้ใช้ลงทะเบียนสำเร็จ, THE Auth_Service SHALL ให้ผู้ใช้ตั้งรหัสผ่านสำหรับใช้งานภายในแอป UniMart แยกจากรหัสผ่าน reg.tu.ac.th (ไม่เก็บรหัสผ่าน TU ในระบบ)
6. IF ผู้ใช้พยายามลงทะเบียนด้วย username (รหัสนักศึกษา) ที่มีบัญชีอยู่แล้วในระบบ, THEN THE Auth_Service SHALL แสดงข้อความ "รหัสนักศึกษานี้ลงทะเบียนแล้ว กรุณาเข้าสู่ระบบ" และปฏิเสธการลงทะเบียนซ้ำ
7. IF การเชื่อมต่อกับ TU API ล้มเหลวหรือ timeout, THEN THE Auth_Service SHALL แสดงข้อความ "ไม่สามารถเชื่อมต่อระบบยืนยันตัวตนได้ กรุณาลองใหม่อีกครั้ง" และไม่อนุญาตให้ลงทะเบียน
8. THE Auth_Service SHALL ไม่เก็บรหัสผ่าน reg.tu.ac.th ของผู้ใช้ในฐานข้อมูล โดยใช้รหัสผ่าน TU เฉพาะตอนยืนยันตัวตนครั้งแรกเท่านั้น

---

### ข้อกำหนดที่ 5: ระบบแจ้งเตือน (Notification System)

**User Story:** ในฐานะนักศึกษาที่ใช้ UniMart ฉันต้องการได้รับการแจ้งเตือนเมื่อมีข้อความแชทใหม่หรือมีการอัปเดตสถานะธุรกรรม เพื่อที่จะไม่พลาดข้อมูลสำคัญ

#### เกณฑ์การยอมรับ (Acceptance Criteria)

1. WHEN ผู้ใช้ได้รับ Message ใหม่ใน Chat_Room ขณะที่ไม่ได้เปิด Chat_Room นั้นอยู่, THE Notification_Service SHALL ส่งการแจ้งเตือนแบบ Push Notification ที่แสดงชื่อผู้ส่งและตัวอย่างข้อความ
2. WHEN สถานะ Transaction เปลี่ยนแปลง (เช่น ยืนยันการซื้อ, จัดส่งแล้ว, รับสินค้าแล้ว), THE Notification_Service SHALL ส่งการแจ้งเตือนไปยังผู้ใช้ที่เกี่ยวข้องกับ Transaction
3. WHEN ผู้ใช้เปิดหน้าแจ้งเตือน, THE Notification_Service SHALL แสดงรายการแจ้งเตือนทั้งหมดเรียงตามลำดับเวลาจากใหม่ไปเก่า พร้อมสถานะอ่านแล้ว/ยังไม่อ่าน
4. WHEN ผู้ใช้กดที่การแจ้งเตือน, THE Notification_Service SHALL นำทางผู้ใช้ไปยังหน้าที่เกี่ยวข้อง (Chat_Room หรือหน้ารายละเอียด Transaction)
5. WHILE ผู้ใช้ปิดการแจ้งเตือนในหน้าตั้งค่า, THE Notification_Service SHALL หยุดส่ง Push Notification ไปยังผู้ใช้คนนั้น แต่ยังคงบันทึกการแจ้งเตือนในระบบ
6. THE Notification_Service SHALL แสดงจำนวนการแจ้งเตือนที่ยังไม่ได้อ่านเป็น Badge บนไอคอนแจ้งเตือนในหน้าหลัก

---

### ข้อกำหนดที่ 6: ระบบธุรกรรม (Transaction Management)

**User Story:** ในฐานะนักศึกษาที่ใช้ UniMart ฉันต้องการติดตามสถานะการซื้อขายและเช่าสินค้าได้ เพื่อที่จะรู้ว่าธุรกรรมอยู่ในขั้นตอนใด

#### เกณฑ์การยอมรับ (Acceptance Criteria)

1. WHEN Buyer กดปุ่ม "ซื้อ" หรือ "เช่า" ในหน้ารายละเอียดสินค้า, THE UniMart_System SHALL สร้าง Transaction ที่มีสถานะเริ่มต้นเป็น "รอยืนยัน" (Pending)
2. WHEN Seller ยืนยัน Transaction, THE UniMart_System SHALL เปลี่ยนสถานะ Transaction เป็น "กำลังดำเนินการ" (Processing) และเปลี่ยนสถานะ Product เป็น "จองแล้ว" (Reserved)
3. WHEN Seller กดยืนยันว่าส่งมอบสินค้าแล้ว, THE UniMart_System SHALL เปลี่ยนสถานะ Transaction เป็น "รอรับสินค้า" (Shipping)
4. WHEN Buyer กดยืนยันว่าได้รับสินค้าแล้ว, THE UniMart_System SHALL เปลี่ยนสถานะ Transaction เป็น "เสร็จสิ้น" (Completed) และเปลี่ยนสถานะ Product เป็น "ขายแล้ว" (Sold)
5. WHEN Seller หรือ Buyer กดปุ่ม "ยกเลิก" ก่อนสถานะ "รอรับสินค้า", THE UniMart_System SHALL เปลี่ยนสถานะ Transaction เป็น "ยกเลิก" (Canceled) และคืนสถานะ Product เป็น "พร้อมขาย" (Available)
6. WHEN ผู้ใช้เปิดหน้าโปรไฟล์, THE UniMart_System SHALL แสดงรายการ Transaction แยกตามหมวด: ประวัติ (History), กำลังดำเนินการ (Processing), รอรับสินค้า (Shipping), ยกเลิก (Canceled)
7. WHILE Product มีสถานะ "จองแล้ว" (Reserved), THE UniMart_System SHALL ป้องกันไม่ให้ Buyer คนอื่นสร้าง Transaction สำหรับ Product เดียวกัน
