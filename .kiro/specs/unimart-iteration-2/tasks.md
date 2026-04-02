# แผนการพัฒนา (Implementation Plan): UniMart Iteration 2

## ภาพรวม

พัฒนาต่อยอด UniMart โดยเพิ่ม 6 ฟีเจอร์หลัก: ระบบแชท, รีวิว/เครดิต, Smart Filter, Enhanced Auth, แจ้งเตือน, และธุรกรรม
เรียงลำดับตาม dependency: Database → Backend API → Frontend Services/Screens → Testing

## Tasks

- [x] 1. Database Migration — เพิ่มตารางใหม่และแก้ไขตารางเดิม
  - [x] 1.1 อัปเดต Prisma Schema — เพิ่ม fields ใหม่ใน users และ Product
    - เพิ่ม `password_hash`, `tu_status`, `dormitory_zone` ใน model `users`
    - เพิ่ม `meetingPointId` และ relation ใน model `Product`
    - เพิ่ม relations สำหรับ Transaction, Review ใน `users` และ `Product`
    - _Requirements: 4.2, 4.5, 3.7_

  - [x] 1.2 เพิ่ม Prisma Models ใหม่ — Transaction, Review, MeetingPoint
    - สร้าง model `Transaction` พร้อม status lifecycle (PENDING → PROCESSING → SHIPPING → COMPLETED/CANCELED)
    - สร้าง model `Review` พร้อม unique constraint `[transactionId, reviewerId]`
    - สร้าง model `MeetingPoint` พร้อม `@@map("meeting_points")`
    - _Requirements: 6.1, 2.1, 3.7_

  - [x] 1.3 สร้างตาราง Supabase โดยตรง — chat_rooms, chat_messages, chat_reports, notifications, notification_settings
    - สร้าง SQL migration สำหรับ `chat_rooms` พร้อม UNIQUE(buyer_id, seller_id, product_id)
    - สร้าง `chat_messages` พร้อม indexes สำหรับ room_id, is_read
    - สร้าง `chat_reports` พร้อม status check constraint
    - สร้าง `notifications` พร้อม JSONB data field และ indexes
    - สร้าง `notification_settings` พร้อม UNIQUE user_id
    - _Requirements: 1.1, 1.6, 1.7, 5.1, 5.5_

  - [x] 1.4 Seed Data — เพิ่มข้อมูล meeting_points เริ่มต้น
    - เพิ่มจุดนัดพบ: โรงอาหารกรีน, SC Hall, ป้ายรถตู้, หอพักเชียงราก, หอพักอินเตอร์โซน
    - _Requirements: 3.3, 3.7_

  - [x] 1.5 รัน Prisma migrate และตรวจสอบ schema
    - รัน `npx prisma migrate dev` และ `npx prisma generate`
    - ตรวจสอบว่า tables ถูกสร้างครบถ้วน
    - _Requirements: 1.1, 2.1, 3.7, 4.2, 5.1, 6.1_

- [x] 2. Checkpoint — ตรวจสอบ Database Migration
  - ตรวจสอบว่า migration สำเร็จ, ตาราง/indexes ถูกสร้างครบ, seed data ถูกต้อง
  - Ensure all tests pass, ask the user if questions arise.

- [x] 3. Backend API — Enhanced Authentication (ปรับปรุงระบบยืนยันตัวตน)
  - [x] 3.1 ติดตั้ง dependencies — bcrypt, jsonwebtoken
    - เพิ่ม `bcrypt` และ `jsonwebtoken` ใน package.json
    - _Requirements: 4.5_

  - [x] 3.2 ปรับปรุง POST /api/auth/verify — เพิ่ม flow ตรวจสอบบัญชีซ้ำ
    - เมื่อ TU API ตอบ status: true → ตรวจสอบว่ามีบัญชีอยู่แล้วหรือไม่
    - ถ้ามีบัญชีแล้ว → ตอบ `action: "LOGIN_EXISTS"`
    - ถ้ายังไม่มี → ตอบ `action: "GO_TO_REGISTER"` พร้อม tuProfile
    - เมื่อ TU API ตอบ status: false → ตอบ 401 พร้อมข้อความภาษาไทย
    - จัดการ TU API timeout/connection error → ตอบ 503
    - _Requirements: 4.1, 4.3, 4.4, 4.6, 4.7_

  - [x] 3.3 ปรับปรุง POST /api/auth/register — เพิ่ม password hashing
    - รับ `app_password` จาก request body
    - Hash ด้วย bcrypt แล้วบันทึกเป็น `password_hash`
    - บันทึกข้อมูล TU profile (tu_status, faculty, department ฯลฯ)
    - ตรวจสอบ username ซ้ำ → ตอบ 409
    - ไม่เก็บรหัสผ่าน TU ในฐานข้อมูล
    - _Requirements: 4.2, 4.5, 4.6, 4.8_

  - [x] 3.4 สร้าง POST /api/auth/login — เข้าสู่ระบบด้วยรหัสผ่าน UniMart
    - รับ username + password → ค้นหา user → bcrypt.compare
    - สำเร็จ → ตอบ user data + JWT token
    - ล้มเหลว → ตอบ 401
    - _Requirements: 4.5_

  - [x] 3.5 Property tests สำหรับ Auth
    - **Property 15: ข้อมูล TU API ถูก map ครบถ้วน**
    - **Property 16: ลงทะเบียนได้ทุก tu_status**
    - **Property 17: รหัสผ่าน UniMart Round-Trip**
    - **Property 18: ห้ามลงทะเบียนซ้ำ**
    - **Property 19: ไม่เก็บรหัสผ่าน TU**
    - **Validates: Requirements 4.2, 4.4, 4.5, 4.6, 4.8**

- [x] 4. Backend API — Chat System (ระบบแชท)
  - [x] 4.1 สร้าง POST /api/chat/rooms — สร้างหรือเปิด Chat Room
    - รับ buyerId, sellerId, productId
    - ตรวจสอบ room ที่มีอยู่แล้ว (UNIQUE constraint) → คืน room เดิม
    - ถ้าไม่มี → สร้าง room ใหม่
    - ใช้ Supabase client สำหรับ chat tables
    - _Requirements: 1.1_

  - [x] 4.2 สร้าง GET /api/chat/rooms/:userId — ดึงรายการ Chat Room
    - ดึง rooms ที่ user เป็น buyer หรือ seller
    - รวมข้อมูล: ชื่อคู่สนทนา, ข้อความล่าสุด, เวลา, unreadCount
    - เรียงตามข้อความล่าสุด (ใหม่สุดก่อน)
    - _Requirements: 1.4_

  - [x] 4.3 สร้าง GET /api/chat/rooms/:roomId/messages — ดึงข้อความ
    - ดึงข้อความทั้งหมดใน room เรียงตาม createdAt ascending
    - รองรับ pagination (limit, offset)
    - _Requirements: 1.3, 1.6_

  - [x] 4.4 สร้าง POST /api/chat/messages — ส่งข้อความ
    - รับ roomId, senderId, content/imageUrl, type (text/image)
    - Validate: ข้อความไม่เปล่า (สำหรับ type text)
    - บันทึกลง chat_messages
    - สร้าง notification สำหรับผู้รับ
    - _Requirements: 1.2, 1.5, 1.6_

  - [x] 4.5 สร้าง POST /api/chat/reports — รายงานผู้ใช้
    - รับ roomId, reporterId, reportedUserId, reason
    - บันทึกลง chat_reports พร้อม status: 'pending'
    - _Requirements: 1.7_

  - [x] 4.6 Property tests สำหรับ Chat
    - **Property 1: Chat Room สร้างแบบ Idempotent**
    - **Property 2: ข้อความเรียงตามลำดับเวลา**
    - **Property 3: ข้อความ Round-Trip (Persistence)**
    - **Property 4: Chat List แสดงข้อมูลครบถ้วน**
    - **Property 5: Report มีข้อมูลครบถ้วน**
    - **Validates: Requirements 1.1, 1.3, 1.4, 1.6, 1.7**

- [x] 5. Backend API — Transaction System (ระบบธุรกรรม)
  - [x] 5.1 สร้าง POST /api/transactions — สร้างธุรกรรมใหม่
    - รับ buyerId, productId, type (SALE/RENT)
    - ตรวจสอบ Product status ≠ Reserved → ถ้า Reserved ตอบ 409
    - ดึง sellerId และ price จาก Product
    - สร้าง Transaction ด้วยสถานะ PENDING
    - _Requirements: 6.1, 6.7_

  - [x] 5.2 สร้าง PATCH /api/transactions/:id/confirm — Seller ยืนยัน
    - ตรวจสอบสถานะปัจจุบัน = PENDING → เปลี่ยนเป็น PROCESSING
    - เปลี่ยน Product status เป็น Reserved
    - สร้าง notification สำหรับ Buyer
    - _Requirements: 6.2_

  - [x] 5.3 สร้าง PATCH /api/transactions/:id/ship — Seller ส่งมอบ
    - ตรวจสอบสถานะปัจจุบัน = PROCESSING → เปลี่ยนเป็น SHIPPING
    - สร้าง notification สำหรับ Buyer
    - _Requirements: 6.3_

  - [x] 5.4 สร้าง PATCH /api/transactions/:id/complete — Buyer ยืนยันรับ
    - ตรวจสอบสถานะปัจจุบัน = SHIPPING → เปลี่ยนเป็น COMPLETED
    - เปลี่ยน Product status เป็น Sold
    - สร้าง notification สำหรับ Seller
    - _Requirements: 6.4_

  - [x] 5.5 สร้าง PATCH /api/transactions/:id/cancel — ยกเลิก
    - ตรวจสอบสถานะปัจจุบัน = PENDING หรือ PROCESSING เท่านั้น
    - ถ้าสถานะอื่น → ตอบ 400
    - เปลี่ยนสถานะเป็น CANCELED, คืน Product status เป็น Available
    - บันทึก canceledBy และ cancelReason
    - สร้าง notification สำหรับอีกฝ่าย
    - _Requirements: 6.5_

  - [x] 5.6 สร้าง GET /api/transactions/user/:userId — ดึงรายการธุรกรรม
    - ดึง transactions ที่ user เป็น buyer หรือ seller
    - จัดกลุ่มตามสถานะ: History (COMPLETED), Processing, Shipping, Canceled
    - รวมข้อมูล Product และคู่ค้า
    - _Requirements: 6.6_

  - [x] 5.7 Property tests สำหรับ Transaction
    - **Property 24: ธุรกรรมใหม่เริ่มต้นที่ PENDING**
    - **Property 25: State Transition ถูกต้องตามวงจรชีวิต**
    - **Property 26: ยกเลิกได้เฉพาะก่อน Shipping**
    - **Property 27: ธุรกรรมจัดกลุ่มตามสถานะถูกต้อง**
    - **Property 28: ห้ามสร้างธุรกรรมซ้ำสำหรับสินค้าที่จองแล้ว**
    - **Validates: Requirements 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7**

- [x] 6. Backend API — Review System (ระบบรีวิว)
  - [x] 6.1 สร้าง POST /api/reviews — สร้างรีวิว
    - รับ transactionId, reviewerId, revieweeId, rating, comment
    - Validate: rating อยู่ในช่วง 1-5 → ถ้าไม่ ตอบ 400
    - ตรวจสอบ Transaction status = COMPLETED → ถ้าไม่ ตอบ 403
    - ตรวจสอบรีวิวซ้ำ (UNIQUE transactionId + reviewerId) → ถ้าซ้ำ ตอบ 409
    - _Requirements: 2.1, 2.2, 2.6, 2.7_

  - [x] 6.2 สร้าง GET /api/reviews/user/:userId — ดึงรีวิวของผู้ใช้
    - ดึง reviews ที่ revieweeId = userId
    - รวมข้อมูล reviewer (displayName)
    - เรียงตาม createdAt descending
    - _Requirements: 2.4_

  - [x] 6.3 สร้าง GET /api/reviews/credit/:userId — ดึง Credit Score
    - คำนวณค่าเฉลี่ย rating ทั้งหมดที่ revieweeId = userId
    - ตอบ: averageRating, totalReviews
    - _Requirements: 2.3, 2.4_

  - [x] 6.4 Property tests สำหรับ Review
    - **Property 6: รีวิวได้เฉพาะธุรกรรมที่เสร็จสิ้น**
    - **Property 7: Credit Score เท่ากับค่าเฉลี่ยคะแนนดาว**
    - **Property 8: โปรไฟล์แสดงข้อมูลรีวิวครบถ้วน**
    - **Property 9: กรองสินค้าตามความน่าเชื่อถือ**
    - **Property 10: ห้ามรีวิวซ้ำ**
    - **Property 11: คะแนนดาวต้องอยู่ในช่วง 1-5**
    - **Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7**

- [x] 7. Backend API — Smart Filter (ระบบกรองอัจฉริยะ)
  - [x] 7.1 สร้าง GET /api/products/filter — กรองสินค้าตามเงื่อนไข
    - รับ query params: faculty, dormitoryZone, meetingPoint, minCredit, categoryId
    - ใช้ AND logic สำหรับเงื่อนไขหลายรายการ
    - กรองตาม faculty ของ seller (join users)
    - กรองตาม dormitoryZone ของ Product location
    - กรองตาม meetingPoint (join meeting_points)
    - กรองตาม minCredit (คำนวณ credit score ของ seller)
    - ตอบ: products array + totalCount
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 2.5_

  - [x] 7.2 สร้าง GET /api/meeting-points — ดึงรายการจุดนัดพบ
    - ดึงข้อมูลจากตาราง meeting_points ทั้งหมด
    - _Requirements: 3.3, 3.7_

  - [x] 7.3 สร้าง GET /api/dormitory-zones — ดึงรายการโซนหอพัก
    - ตอบ: รายการโซนหอพัก (เชียงราก, อินเตอร์โซน, ในมหาวิทยาลัย)
    - _Requirements: 3.2_

  - [x] 7.4 Property tests สำหรับ Smart Filter
    - **Property 12: Smart Filter — AND Logic ถูกต้อง**
    - **Property 13: ล้างตัวกรองคืนสินค้าทั้งหมด**
    - **Property 14: จำนวนสินค้าตรงกับผลลัพธ์**
    - **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6**

- [x] 8. Backend API — Notification System (ระบบแจ้งเตือน)
  - [x] 8.1 สร้าง GET /api/notifications/:userId — ดึงรายการแจ้งเตือน
    - ดึง notifications ของ user เรียงตาม createdAt descending
    - รวมสถานะ is_read
    - _Requirements: 5.3_

  - [x] 8.2 สร้าง PATCH /api/notifications/:id/read — อ่านแจ้งเตือน
    - อัปเดต is_read = true
    - _Requirements: 5.3, 5.4_

  - [x] 8.3 สร้าง GET /api/notifications/:userId/unread-count — จำนวนยังไม่อ่าน
    - นับ notifications ที่ is_read = false ของ user
    - _Requirements: 5.6_

  - [x] 8.4 สร้าง PATCH /api/notifications/:userId/settings — ตั้งค่าแจ้งเตือน
    - อัปเดต push_enabled, chat_notifications, transaction_notifications
    - อัปเดต fcm_token
    - _Requirements: 5.5_

  - [x] 8.5 สร้าง Notification Helper — ฟังก์ชันสร้างแจ้งเตือนภายใน
    - สร้างฟังก์ชัน `createNotification(userId, type, title, body, data)`
    - ตรวจสอบ notification_settings ของ user → ถ้า push_enabled → ส่ง FCM
    - บันทึก notification ลงตารางเสมอ (แม้ปิด push)
    - จัดการ FCM error: log error, retry 3 ครั้ง, ยังบันทึก notification
    - _Requirements: 5.1, 5.2, 5.5_

  - [x] 8.6 Property tests สำหรับ Notification
    - **Property 20: แจ้งเตือนเมื่อสถานะธุรกรรมเปลี่ยน**
    - **Property 21: แจ้งเตือนเรียงจากใหม่ไปเก่า**
    - **Property 22: ปิด Push แต่ยังบันทึกแจ้งเตือน**
    - **Property 23: จำนวน Badge ตรงกับแจ้งเตือนที่ยังไม่อ่าน**
    - **Validates: Requirements 5.2, 5.3, 5.5, 5.6**

- [ ] 9. Checkpoint — ตรวจสอบ Backend API ทั้งหมด
  - ตรวจสอบว่า API endpoints ทั้งหมดทำงานถูกต้อง
  - Ensure all tests pass, ask the user if questions arise.

- [x] 10. Frontend Models — สร้าง Dart Models ใหม่
  - [x] 10.1 สร้าง ChatRoom model (`frontend/lib/models/chat_room.dart`)
    - Fields: id, buyerId, sellerId, productId, productTitle, otherUserName, lastMessage, lastMessageTime, unreadCount
    - fromJson / toJson
    - _Requirements: 1.4_

  - [x] 10.2 สร้าง ChatMessage model (`frontend/lib/models/chat_message.dart`)
    - Fields: id, roomId, senderId, content, imageUrl, type (text/image), isRead, createdAt
    - fromJson / toJson
    - _Requirements: 1.2, 1.3_

  - [x] 10.3 สร้าง Transaction model (`frontend/lib/models/transaction.dart`)
    - Fields: id, buyerId, sellerId, productId, type, status, price, meetingPoint, createdAt, updatedAt
    - รวม product info และ user info
    - fromJson / toJson
    - _Requirements: 6.1, 6.6_

  - [x] 10.4 สร้าง Review model (`frontend/lib/models/review.dart`)
    - Fields: id, transactionId, reviewerId, revieweeId, rating, comment, createdAt, reviewerName
    - fromJson / toJson
    - _Requirements: 2.1, 2.4_

  - [x] 10.5 สร้าง AppNotification model (`frontend/lib/models/app_notification.dart`)
    - Fields: id, userId, type, title, body, data, isRead, createdAt
    - fromJson / toJson
    - _Requirements: 5.3_

- [x] 11. Frontend Services — สร้าง Service Layer
  - [x] 11.1 ปรับปรุง AuthService (`frontend/lib/services/auth_service.dart`)
    - สร้างไฟล์ใหม่แยกจาก api_service.dart
    - เพิ่ม `verify(username, password)` → เรียก POST /api/auth/verify
    - เพิ่ม `register(userData, appPassword)` → เรียก POST /api/auth/register
    - เพิ่ม `login(username, password)` → เรียก POST /api/auth/login
    - จัดเก็บ JWT token ใน SharedPreferences
    - _Requirements: 4.1, 4.2, 4.5_

  - [x] 11.2 สร้าง ChatService (`frontend/lib/services/chat_service.dart`)
    - `createOrOpenRoom(buyerId, sellerId, productId)` → POST /api/chat/rooms
    - `getRooms(userId)` → GET /api/chat/rooms/:userId
    - `getMessages(roomId)` → GET /api/chat/rooms/:roomId/messages
    - `sendMessage(roomId, senderId, content, type)` → POST /api/chat/messages
    - `reportUser(roomId, reporterId, reportedUserId, reason)` → POST /api/chat/reports
    - `subscribeToMessages(roomId)` → Supabase Realtime subscription
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.7_

  - [x] 11.3 สร้าง TransactionService (`frontend/lib/services/transaction_service.dart`)
    - `createTransaction(buyerId, productId, type)` → POST /api/transactions
    - `confirmTransaction(id)` → PATCH /api/transactions/:id/confirm
    - `shipTransaction(id)` → PATCH /api/transactions/:id/ship
    - `completeTransaction(id)` → PATCH /api/transactions/:id/complete
    - `cancelTransaction(id, canceledBy, reason)` → PATCH /api/transactions/:id/cancel
    - `getUserTransactions(userId)` → GET /api/transactions/user/:userId
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6_

  - [x] 11.4 สร้าง ReviewService (`frontend/lib/services/review_service.dart`)
    - `createReview(transactionId, reviewerId, revieweeId, rating, comment)` → POST /api/reviews
    - `getUserReviews(userId)` → GET /api/reviews/user/:userId
    - `getCreditScore(userId)` → GET /api/reviews/credit/:userId
    - _Requirements: 2.1, 2.3, 2.4_

  - [x] 11.5 สร้าง NotificationService (`frontend/lib/services/notification_service.dart`)
    - `getNotifications(userId)` → GET /api/notifications/:userId
    - `markAsRead(notificationId)` → PATCH /api/notifications/:id/read
    - `getUnreadCount(userId)` → GET /api/notifications/:userId/unread-count
    - `updateSettings(userId, settings)` → PATCH /api/notifications/:userId/settings
    - ตั้งค่า FCM token registration
    - _Requirements: 5.1, 5.3, 5.4, 5.5, 5.6_

  - [x] 11.6 สร้าง FilterService (`frontend/lib/services/filter_service.dart`)
    - `filterProducts(faculty, dormitoryZone, meetingPoint, minCredit, categoryId)` → GET /api/products/filter
    - `getMeetingPoints()` → GET /api/meeting-points
    - `getDormitoryZones()` → GET /api/dormitory-zones
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

- [x] 12. Frontend Screens — Authentication (ปรับปรุงหน้า Login/Register)
  - [x] 12.1 ปรับปรุง LoginScreen — เพิ่ม flow login ด้วยรหัสผ่าน UniMart
    - เพิ่มฟิลด์ password สำหรับ UniMart password
    - เมื่อ verify สำเร็จ + มีบัญชีแล้ว → login ด้วย UniMart password
    - เมื่อ verify สำเร็จ + ยังไม่มีบัญชี → ไปหน้า Register
    - แสดง error messages ภาษาไทยตาม design
    - _Requirements: 4.1, 4.3, 4.5, 4.7_

  - [x] 12.2 ปรับปรุง RegisterScreen — เพิ่มฟิลด์ตั้งรหัสผ่าน UniMart
    - เพิ่มฟิลด์ app_password และ confirm_password
    - แสดงข้อมูล TU profile ที่ได้จาก verify (อ่านอย่างเดียว)
    - แสดงคำเตือนถ้า tu_status ไม่ใช่ "ปกติ"
    - เพิ่มฟิลด์ dormitory_zone (dropdown)
    - _Requirements: 4.2, 4.4, 4.5_

- [x] 13. Frontend Screens — Chat System (หน้าแชท)
  - [x] 13.1 สร้าง ChatListScreen (`frontend/lib/screens/chat_list_screen.dart`)
    - แสดงรายการ Chat Room ทั้งหมดของผู้ใช้
    - แต่ละ item แสดง: ชื่อคู่สนทนา, ข้อความล่าสุด, เวลา, badge จำนวนยังไม่อ่าน
    - กดที่ room → นำทางไป ChatRoomScreen
    - _Requirements: 1.4_

  - [x] 13.2 สร้าง ChatRoomScreen (`frontend/lib/screens/chat_room_screen.dart`)
    - แสดงข้อความทั้งหมดเรียงตามเวลา (เก่า → ใหม่)
    - ช่องพิมพ์ข้อความ + ปุ่มส่ง + ปุ่มแนบรูป
    - Supabase Realtime subscription สำหรับข้อความใหม่
    - แสดงสถานะ "ส่งไม่สำเร็จ" + ปุ่ม "ส่งซ้ำ" เมื่อเครือข่ายขาดหาย
    - ปุ่ม "รายงาน" ใน AppBar → แสดง dialog เลือกเหตุผล
    - _Requirements: 1.2, 1.3, 1.5, 1.7, 1.8_

  - [x] 13.3 เพิ่มปุ่ม "แชท" ใน ProductDetailScreen
    - เพิ่มปุ่ม "แชทกับผู้ขาย" ในหน้ารายละเอียดสินค้า
    - กด → เรียก ChatService.createOrOpenRoom → นำทางไป ChatRoomScreen
    - _Requirements: 1.1_

- [x] 14. Frontend Screens — Transaction System (หน้าธุรกรรม)
  - [x] 14.1 สร้าง TransactionListScreen (`frontend/lib/screens/transaction_list_screen.dart`)
    - แสดงรายการธุรกรรมแยกตาม tabs: กำลังดำเนินการ, รอรับสินค้า, ประวัติ, ยกเลิก
    - แต่ละ item แสดง: ชื่อสินค้า, ราคา, สถานะ, คู่ค้า
    - กดที่ item → นำทางไป TransactionDetailScreen
    - _Requirements: 6.6_

  - [x] 14.2 สร้าง TransactionDetailScreen (`frontend/lib/screens/transaction_detail_screen.dart`)
    - แสดงรายละเอียดธุรกรรม: สินค้า, ราคา, สถานะ, คู่ค้า, จุดนัดพบ
    - ปุ่มเปลี่ยนสถานะตาม role (Buyer/Seller) และสถานะปัจจุบัน:
      - Seller + PENDING → ปุ่ม "ยืนยัน" / "ยกเลิก"
      - Seller + PROCESSING → ปุ่ม "ส่งมอบแล้ว" / "ยกเลิก"
      - Buyer + SHIPPING → ปุ่ม "ได้รับสินค้าแล้ว"
    - เมื่อ COMPLETED → แสดงปุ่ม "เขียนรีวิว" (ถ้ายังไม่ได้รีวิว)
    - _Requirements: 6.2, 6.3, 6.4, 6.5_

  - [x] 14.3 เพิ่มปุ่ม "ซื้อ/เช่า" ใน ProductDetailScreen
    - เพิ่มปุ่ม "ซื้อ" หรือ "เช่า" ตาม Product type
    - กด → เรียก TransactionService.createTransaction
    - แสดง error ถ้าสินค้าถูกจองแล้ว
    - _Requirements: 6.1, 6.7_

- [x] 15. Frontend Screens — Review System (หน้ารีวิว)
  - [x] 15.1 สร้าง ReviewScreen (`frontend/lib/screens/review_screen.dart`)
    - ฟอร์มเขียนรีวิว: เลือกคะแนนดาว (1-5) + ข้อความรีวิว
    - Validate: คะแนนดาวต้องเลือก, ข้อความ optional
    - ส่ง → เรียก ReviewService.createReview
    - แสดง error ถ้ารีวิวซ้ำ หรือ rating ไม่ถูกต้อง
    - _Requirements: 2.1, 2.2, 2.6, 2.7_

  - [x] 15.2 สร้าง UserProfileScreen (`frontend/lib/screens/user_profile_screen.dart`)
    - แสดง Credit Score (ดาวเฉลี่ย), จำนวนรีวิวทั้งหมด
    - แสดงรายการรีวิวล่าสุด
    - แสดงข้อมูลผู้ใช้: ชื่อ, คณะ, สถานะ TU
    - _Requirements: 2.3, 2.4_

- [x] 16. Frontend Screens — Smart Filter & Notification
  - [x] 16.1 สร้าง FilterSheet (`frontend/lib/screens/filter_sheet.dart`)
    - Bottom Sheet แสดงตัวเลือกกรอง: คณะ, โซนหอพัก, จุดนัดพบ, คะแนนเครดิตขั้นต่ำ
    - ดึงข้อมูล meeting points และ dormitory zones จาก API
    - ปุ่ม "ค้นหา" → เรียก FilterService.filterProducts
    - ปุ่ม "ล้างตัวกรอง" → รีเซ็ตเงื่อนไขทั้งหมด
    - แสดงจำนวนสินค้าที่ตรงเงื่อนไข
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

  - [x] 16.2 เพิ่มปุ่ม Filter ใน HomeScreen
    - เพิ่มไอคอน filter ใน AppBar ของ HomeScreen
    - กด → แสดง FilterSheet
    - เมื่อกรอง → อัปเดตรายการสินค้าตามผลลัพธ์
    - _Requirements: 3.1_

  - [x] 16.3 สร้าง NotificationScreen (`frontend/lib/screens/notification_screen.dart`)
    - แสดงรายการแจ้งเตือนเรียงจากใหม่ไปเก่า
    - แต่ละ item แสดง: title, body, เวลา, สถานะอ่าน/ยังไม่อ่าน
    - กดที่ item → mark as read + นำทางไปหน้าที่เกี่ยวข้อง (ChatRoom/TransactionDetail)
    - _Requirements: 5.3, 5.4_

  - [x] 16.4 เพิ่ม Notification Badge ใน MainScreen
    - แสดง badge จำนวนแจ้งเตือนที่ยังไม่อ่านบนไอคอนแจ้งเตือน
    - เรียก NotificationService.getUnreadCount เป็นระยะ
    - _Requirements: 5.6_

  - [x] 16.5 ตั้งค่า FCM ใน Flutter App
    - ตั้งค่า Firebase Cloud Messaging สำหรับ push notification
    - ลงทะเบียน FCM token เมื่อ login สำเร็จ
    - จัดการ notification tap → นำทางไปหน้าที่เกี่ยวข้อง
    - _Requirements: 5.1, 5.2, 5.4_

- [x] 17. Frontend — เพิ่ม Meeting Point ในหน้าลงขายสินค้า
  - [x] 17.1 ปรับปรุง AddProductScreen — เพิ่มฟิลด์เลือกจุดนัดพบ
    - เพิ่ม dropdown เลือก Meeting Point จากรายการที่ดึงจาก API
    - ส่ง meetingPointId ไปพร้อมกับข้อมูลสินค้า
    - _Requirements: 3.7_

  - [x] 17.2 ปรับปรุง Backend POST /api/products — รับ meetingPointId
    - เพิ่ม meetingPointId ใน product creation
    - _Requirements: 3.7_

- [x] 18. Frontend — Navigation & Wiring (เชื่อมต่อทุกส่วน)
  - [x] 18.1 อัปเดต MainScreen — เพิ่ม tabs/navigation สำหรับ Chat, Notification
    - เพิ่ม tab หรือ navigation item สำหรับ ChatListScreen
    - เพิ่ม icon แจ้งเตือนพร้อม badge ใน AppBar
    - _Requirements: 1.4, 5.6_

  - [x] 18.2 อัปเดต Navigation Routes
    - เพิ่ม routes สำหรับ screens ใหม่ทั้งหมด
    - เชื่อมต่อ TransactionListScreen จากหน้า Profile
    - เชื่อมต่อ UserProfileScreen จากหน้า Chat/Product
    - _Requirements: 5.4, 6.6_

- [x] 19. Checkpoint สุดท้าย — ตรวจสอบระบบทั้งหมด
  - ตรวจสอบว่า Frontend เชื่อมต่อกับ Backend ได้ถูกต้อง
  - ตรวจสอบ flow ทั้งหมด: Auth → Chat → Transaction → Review → Notification
  - Ensure all tests pass, ask the user if questions arise.

## หมายเหตุ

- Tasks ที่มี `*` เป็น optional สามารถข้ามได้สำหรับ MVP
- ทุก task อ้างอิง requirements เฉพาะเพื่อ traceability
- Checkpoints ช่วยตรวจสอบความถูกต้องเป็นระยะ
- Property tests ใช้ fast-check library ตรวจสอบ correctness properties 28 ข้อ
- Unit tests ครอบคลุม edge cases และ error conditions
- Backend ใช้ JavaScript (Node.js/Express + Prisma), Frontend ใช้ Dart (Flutter)
