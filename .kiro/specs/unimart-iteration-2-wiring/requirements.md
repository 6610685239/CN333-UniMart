# เอกสารข้อกำหนด (Requirements Document) — UniMart Iteration 2 Wiring

## บทนำ

เอกสารนี้ครอบคลุมงานค้างจาก UniMart Iteration 2 ที่ต้องทำต่อเพื่อให้ระบบทำงานได้จริง (end-to-end wiring) ประกอบด้วย 4 กลุ่มงานหลัก:
1. Sync Database Schema และ Seed Data — ให้ Supabase มีตารางและข้อมูลพื้นฐานครบถ้วน
2. Wire Notification — เชื่อมต่อระบบแจ้งเตือนเข้ากับ Transaction endpoints และ Chat messages ที่ยังเป็น TODO
3. แก้ไข Frontend ให้ดึงข้อมูลจาก API จริงแทน mock data
4. แก้ไข Bug ที่ทำให้ Frontend กับ Backend ไม่สื่อสารกันถูกต้อง (field name mismatch, response format mismatch)

## อภิธานศัพท์ (Glossary)

- **UniMart_System**: ระบบแอปพลิเคชัน UniMart ทั้ง Frontend (Flutter) และ Backend (Node.js/Express)
- **Prisma_Schema**: ไฟล์ `backend/prisma/schema.prisma` ที่กำหนดโครงสร้างฐานข้อมูลผ่าน Prisma ORM
- **Supabase_DB**: ฐานข้อมูล PostgreSQL บน Supabase ที่ใช้เป็น production database
- **Notification_Service**: บริการแจ้งเตือนภายใน backend (`backend/services/notification.service.js`)
- **Transaction_Controller**: controller ที่จัดการ HTTP endpoints สำหรับธุรกรรม (`backend/controllers/transaction.controller.js`)
- **Chat_Controller**: controller ที่จัดการ HTTP endpoints สำหรับแชท (`backend/controllers/chat.controller.js`)
- **HomePage**: หน้าหลักของแอป Flutter ที่แสดงรายการสินค้า (`frontend/lib/pages/home_page.dart`)
- **MainScreen**: หน้าจอหลักที่มี BottomNavigationBar (`frontend/lib/screens/main_screen.dart`)
- **Seed_Script**: สคริปต์สำหรับเพิ่มข้อมูลเริ่มต้นลงฐานข้อมูล (categories, meeting_points)
- **Product_API**: endpoint `GET /api/products` สำหรับดึงรายการสินค้าจาก backend
- **kAllProducts**: ข้อมูลสินค้า hardcoded ใน `favourite_manager.dart` ที่ใช้แสดงผลบน HomePage ปัจจุบัน
- **TransactionService_Flutter**: service class ใน Flutter (`frontend/lib/services/transaction_service.dart`) สำหรับเรียก Transaction API
- **NotificationService_Flutter**: service class ใน Flutter (`frontend/lib/services/notification_service.dart`) สำหรับเรียก Notification API
- **AddProductScreen**: หน้าจอลงขายสินค้าใหม่ใน Flutter

## ข้อกำหนด (Requirements)

---

### ข้อกำหนดที่ 1: Sync Database Schema ไปยัง Supabase

**User Story:** ในฐานะนักพัฒนา ฉันต้องการให้ Prisma Schema ถูก sync ไปยัง Supabase Database เพื่อที่ตาราง Transaction, Review, MeetingPoint และ field meetingPointId จะมีอยู่จริงบน production database

#### เกณฑ์การยอมรับ (Acceptance Criteria)

1. WHEN นักพัฒนารัน `npx prisma db push` จาก directory `backend/`, THE Prisma_Schema SHALL sync ตาราง Transaction, Review, MeetingPoint (meeting_points) และ field meetingPointId ใน Product ไปยัง Supabase_DB โดยไม่เกิด error
2. THE Supabase_DB SHALL มีตาราง Transaction ที่มี columns: id, buyerId, sellerId, productId, type, status, price, meetingPoint, canceledBy, cancelReason, createdAt, updatedAt พร้อม indexes ตาม Prisma_Schema
3. THE Supabase_DB SHALL มีตาราง Review ที่มี columns: id, transactionId, reviewerId, revieweeId, rating, comment, createdAt พร้อม unique constraint บน (transactionId, reviewerId)
4. THE Supabase_DB SHALL มีตาราง meeting_points ที่มี columns: id, name, zone พร้อม unique constraint บน name
5. THE Supabase_DB SHALL มี column meetingPointId ใน Product table ที่เป็น foreign key ไปยัง meeting_points(id)

---

### ข้อกำหนดที่ 2: Seed ข้อมูลหมวดหมู่สินค้า (Categories)

**User Story:** ในฐานะนักพัฒนา ฉันต้องการเพิ่มข้อมูลหมวดหมู่สินค้าลงในตาราง Category เพื่อที่ผู้ใช้จะสามารถเลือกหมวดหมู่เมื่อลงขายสินค้าและกรองสินค้าตามหมวดหมู่ได้

#### เกณฑ์การยอมรับ (Acceptance Criteria)

1. WHEN นักพัฒนารัน seed script, THE Seed_Script SHALL เพิ่มข้อมูลหมวดหมู่ลงตาราง Category อย่างน้อย 8 รายการ ได้แก่: Textbooks, Uniforms, Gadgets, Accessories, Stationery, Dorm Essentials, Sports, Others
2. IF ข้อมูลหมวดหมู่มีอยู่แล้วในตาราง Category, THEN THE Seed_Script SHALL ข้ามการเพิ่มข้อมูลซ้ำ (upsert) โดยไม่เกิด error
3. THE Seed_Script SHALL สร้างไฟล์ `backend/prisma/seed.js` ที่สามารถรันซ้ำได้อย่างปลอดภัย (idempotent)

---

### ข้อกำหนดที่ 3: Seed ข้อมูลจุดนัดพบ (Meeting Points)

**User Story:** ในฐานะนักพัฒนา ฉันต้องการเพิ่มข้อมูลจุดนัดพบ 5 จุดลงในตาราง meeting_points เพื่อที่ผู้ใช้จะสามารถเลือกจุดนัดพบเมื่อลงขายสินค้าได้

#### เกณฑ์การยอมรับ (Acceptance Criteria)

1. WHEN นักพัฒนารัน seed script, THE Seed_Script SHALL เพิ่มจุดนัดพบ 5 รายการลงตาราง meeting_points: โรงอาหารกรีน (zone: ในมหาวิทยาลัย), SC Hall (zone: ในมหาวิทยาลัย), ป้ายรถตู้ (zone: ในมหาวิทยาลัย), หอพักเชียงราก (zone: เชียงราก), หอพักอินเตอร์โซน (zone: อินเตอร์โซน)
2. IF ข้อมูลจุดนัดพบมีอยู่แล้วในตาราง meeting_points, THEN THE Seed_Script SHALL ข้ามการเพิ่มข้อมูลซ้ำ (upsert) โดยไม่เกิด error

---

### ข้อกำหนดที่ 4: Wire Notification ใน Transaction Endpoints

**User Story:** ในฐานะผู้ใช้ UniMart ฉันต้องการได้รับแจ้งเตือนเมื่อสถานะธุรกรรมเปลี่ยนแปลง (ยืนยัน, ส่งมอบ, เสร็จสิ้น, ยกเลิก) เพื่อที่จะติดตามสถานะการซื้อขายได้โดยไม่ต้องเปิดแอปตรวจสอบเอง

#### เกณฑ์การยอมรับ (Acceptance Criteria)

1. WHEN Seller ยืนยัน Transaction (confirm), THE Transaction_Controller SHALL เรียก Notification_Service.createNotification เพื่อส่งแจ้งเตือนไปยัง Buyer ที่มี type เป็น "transaction_update" พร้อม title และ body ที่ระบุว่าธุรกรรมถูกยืนยันแล้ว
2. WHEN Seller กดส่งมอบสินค้า (ship), THE Transaction_Controller SHALL เรียก Notification_Service.createNotification เพื่อส่งแจ้งเตือนไปยัง Buyer ที่มี type เป็น "transaction_update" พร้อม title และ body ที่ระบุว่าสินค้าถูกส่งมอบแล้ว
3. WHEN Buyer ยืนยันรับสินค้า (complete), THE Transaction_Controller SHALL เรียก Notification_Service.createNotification เพื่อส่งแจ้งเตือนไปยัง Seller ที่มี type เป็น "transaction_update" พร้อม title และ body ที่ระบุว่าธุรกรรมเสร็จสิ้น
4. WHEN ผู้ใช้ยกเลิกธุรกรรม (cancel), THE Transaction_Controller SHALL เรียก Notification_Service.createNotification เพื่อส่งแจ้งเตือนไปยังอีกฝ่ายหนึ่ง (ถ้า Buyer ยกเลิก → แจ้ง Seller, ถ้า Seller ยกเลิก → แจ้ง Buyer) ที่มี type เป็น "transaction_update"
5. IF การสร้าง notification ล้มเหลว, THEN THE Transaction_Controller SHALL log error แต่ยังคง return response สำเร็จของ transaction operation (notification failure ไม่ควรทำให้ transaction ล้มเหลว)

---

### ข้อกำหนดที่ 5: Wire Notification ใน Chat Messages

**User Story:** ในฐานะผู้ใช้ UniMart ฉันต้องการได้รับแจ้งเตือนเมื่อมีข้อความแชทใหม่ เพื่อที่จะไม่พลาดข้อความจากคู่ค้า

#### เกณฑ์การยอมรับ (Acceptance Criteria)

1. WHEN ผู้ใช้ส่งข้อความใน Chat Room สำเร็จ, THE Chat_Controller SHALL เรียก Notification_Service.createNotification เพื่อส่งแจ้งเตือนไปยังผู้รับ (คู่สนทนาอีกฝ่าย) ที่มี type เป็น "chat_message" พร้อม title ที่แสดงชื่อผู้ส่ง และ body ที่แสดงตัวอย่างข้อความ
2. THE Chat_Controller SHALL ระบุผู้รับ notification โดยดึง buyer_id และ seller_id จาก chat_room แล้วส่งแจ้งเตือนไปยังฝ่ายที่ไม่ใช่ผู้ส่ง
3. IF การสร้าง notification ล้มเหลว, THEN THE Chat_Controller SHALL log error แต่ยังคง return response สำเร็จของ message (notification failure ไม่ควรทำให้การส่งข้อความล้มเหลว)

---

### ข้อกำหนดที่ 6: แก้ไข HomePage ให้ดึงสินค้าจาก API จริง

**User Story:** ในฐานะผู้ใช้ UniMart ฉันต้องการเห็นสินค้าจริงที่ลงขายในระบบบนหน้า Home เพื่อที่จะเลือกซื้อสินค้าที่มีอยู่จริงได้

#### เกณฑ์การยอมรับ (Acceptance Criteria)

1. THE HomePage SHALL ดึงข้อมูลสินค้าจาก Product_API (`GET /api/products`) แทนการใช้ kAllProducts (hardcoded data)
2. WHEN HomePage โหลดข้อมูลสินค้าจาก API, THE HomePage SHALL แสดงรายการสินค้าในส่วน "Trending Now" โดยใช้ข้อมูลจริง ได้แก่ title, price, images, category จาก Product model
3. WHILE HomePage กำลังโหลดข้อมูลจาก API, THE HomePage SHALL แสดง loading indicator ให้ผู้ใช้ทราบ
4. IF การดึงข้อมูลจาก API ล้มเหลว, THEN THE HomePage SHALL แสดงข้อความแจ้งเตือนและให้ผู้ใช้กดลองใหม่ได้
5. THE HomePage SHALL รับ currentUserId เป็น parameter เพื่อกรองสินค้าของตัวเองออกจากรายการ

---

### ข้อกำหนดที่ 7: แก้ไข Navigation ใน HomePage Bottom Nav

**User Story:** ในฐานะผู้ใช้ UniMart ฉันต้องการกดปุ่ม Sell, Chat, และ Profile ใน bottom navigation bar แล้วนำทางไปยังหน้าที่ถูกต้อง เพื่อที่จะเข้าถึงฟีเจอร์ต่างๆ ของแอปได้

#### เกณฑ์การยอมรับ (Acceptance Criteria)

1. WHEN ผู้ใช้กดปุ่ม "Sell" ใน bottom navigation bar ของ HomePage, THE HomePage SHALL นำทางผู้ใช้ไปยัง AddProductScreen
2. WHEN ผู้ใช้กดปุ่ม "Chat" ใน bottom navigation bar ของ HomePage, THE HomePage SHALL นำทางผู้ใช้ไปยัง ChatListScreen
3. WHEN ผู้ใช้กดปุ่ม "Profile" ใน bottom navigation bar ของ HomePage, THE HomePage SHALL นำทางผู้ใช้ไปยังหน้าโปรไฟล์ที่แสดงข้อมูลผู้ใช้และรายการธุรกรรม

---

### ข้อกำหนดที่ 8: แก้ไข NotificationService.getUnreadCount Field Name Mismatch

**User Story:** ในฐานะนักพัฒนา ฉันต้องการให้ Frontend อ่านจำนวนแจ้งเตือนที่ยังไม่อ่านได้ถูกต้อง เพื่อที่ badge บนไอคอนแจ้งเตือนจะแสดงจำนวนที่ถูกต้อง

#### เกณฑ์การยอมรับ (Acceptance Criteria)

1. THE NotificationService_Flutter SHALL อ่านค่า unread count จาก response field ที่ตรงกับ backend — backend ส่ง `{ "unreadCount": N }` ดังนั้น Flutter ต้องอ่านจาก `data['unreadCount']` (ปัจจุบันอ่านจาก `data['count']` ซึ่งไม่ตรงกัน)
2. WHEN backend ส่ง response สำเร็จ, THE NotificationService_Flutter.getUnreadCount SHALL return ค่า integer ที่ตรงกับจำนวน notification ที่ยังไม่อ่านจริง

---

### ข้อกำหนดที่ 9: แก้ไข TransactionService.getUserTransactions Response Format Mismatch

**User Story:** ในฐานะนักพัฒนา ฉันต้องการให้ Flutter parse ข้อมูลธุรกรรมจาก backend ได้ถูกต้อง เพื่อที่หน้า TransactionListScreen จะแสดงรายการธุรกรรมได้

#### เกณฑ์การยอมรับ (Acceptance Criteria)

1. THE TransactionService_Flutter.getUserTransactions SHALL parse response จาก backend ที่เป็น grouped object `{ "processing": [...], "shipping": [...], "history": [...], "canceled": [...] }` ได้ถูกต้อง (ปัจจุบัน Flutter พยายาม parse เป็น `List` ตรงๆ ซึ่งจะ error เพราะ backend ส่ง object)
2. THE TransactionService_Flutter SHALL return ข้อมูลธุรกรรมในรูปแบบที่ TransactionListScreen สามารถแสดงผลแยกตาม tabs (กำลังดำเนินการ, รอรับสินค้า, ประวัติ, ยกเลิก) ได้
3. IF backend ส่ง response ที่ไม่ใช่ format ที่คาดหวัง, THEN THE TransactionService_Flutter SHALL return error message ที่ชัดเจนแทนการ crash

---

### ข้อกำหนดที่ 10: แก้ไขหน้า Favourited ให้ทำงานกับข้อมูลจริง

**User Story:** ในฐานะผู้ใช้ UniMart ฉันต้องการกดถูกใจสินค้าและดูรายการสินค้าที่ถูกใจได้ เพื่อที่จะกลับมาดูสินค้าที่สนใจได้ภายหลัง

#### เกณฑ์การยอมรับ (Acceptance Criteria)

1. THE UniMart_System SHALL ใช้ตาราง product_favourites ที่มีอยู่แล้วใน Prisma_Schema สำหรับเก็บข้อมูลสินค้าที่ถูกใจ แทนการใช้ข้อมูล mock ใน FavouriteManager
2. WHEN ผู้ใช้กดถูกใจสินค้า, THE UniMart_System SHALL บันทึกข้อมูลลงตาราง product_favourites ผ่าน API
3. WHEN ผู้ใช้เปิดหน้า Favourited, THE UniMart_System SHALL ดึงรายการสินค้าที่ถูกใจจาก API และแสดงข้อมูลสินค้าจริง
