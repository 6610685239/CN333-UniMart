# Implementation Plan: UniMart Iteration 2 Wiring

## Overview

งาน wiring/integration ที่เหลือจาก Iteration 2 เพื่อให้ระบบทำงาน end-to-end จริง ครอบคลุม: sync DB schema, seed data, wire notifications, แก้ frontend ให้ใช้ข้อมูลจริง, และแก้ bug field/format mismatch

## Tasks

- [x] 1. Sync Prisma Schema ไปยัง Supabase และสร้าง Seed Script
  - [x] 1.1 สร้างไฟล์ `backend/prisma/seed.js` สำหรับ seed categories และ meeting points
    - สร้าง seed script ที่ใช้ Prisma Client upsert ข้อมูล 8 categories (Textbooks, Uniforms, Gadgets, Accessories, Stationery, Dorm Essentials, Sports, Others) และ 5 meeting points (โรงอาหารกรีน, SC Hall, ป้ายรถตู้, หอพักเชียงราก, หอพักอินเตอร์โซน) พร้อม zone
    - Script ต้อง idempotent — รันซ้ำได้โดยไม่เกิด error หรือข้อมูลซ้ำ
    - เพิ่ม `prisma.seed` config ใน `backend/package.json` ให้ชี้ไปที่ `prisma/seed.js`
    - _Requirements: 1.1, 2.1, 2.2, 2.3, 3.1, 3.2_

  - [x] 1.2 เขียน property test สำหรับ Seed Script Idempotent
    - **Property 1: Seed Script Idempotent**
    - ทดสอบว่ารัน seed กี่ครั้งก็ได้ จำนวน categories = 8 และ meeting_points = 5 เสมอ
    - **Validates: Requirements 2.2, 3.2**

- [x] 2. Checkpoint — ตรวจสอบ DB sync และ seed data
  - ให้นักพัฒนารัน `npx prisma db push` และ `npx prisma db seed` แล้วตรวจสอบว่าตาราง Transaction, Review, meeting_points, Category มีข้อมูลครบถ้วน
  - Ensure all tests pass, ask the user if questions arise.

- [x] 3. Wire Notification ใน Transaction Controller
  - [x] 3.1 เพิ่ม notification calls ใน `backend/controllers/transaction.controller.js`
    - Import `notificationService` จาก `../services/notification.service`
    - เพิ่ม `notificationService.createNotification()` ใน function `confirm()`: ส่งแจ้งเตือนไปยัง buyer (type: "transaction_update", title: "ธุรกรรมถูกยืนยัน", body: "ผู้ขายยืนยันธุรกรรมของคุณแล้ว")
    - เพิ่มใน function `ship()`: ส่งแจ้งเตือนไปยัง buyer (title: "สินค้าถูกส่งมอบ", body: "ผู้ขายส่งมอบสินค้าแล้ว")
    - เพิ่มใน function `complete()`: ส่งแจ้งเตือนไปยัง seller (title: "ธุรกรรมเสร็จสิ้น", body: "ผู้ซื้อยืนยันรับสินค้าแล้ว")
    - เพิ่มใน function `cancel()`: ส่งแจ้งเตือนไปยังอีกฝ่าย (ถ้า canceledBy == buyerId → แจ้ง seller, ถ้า canceledBy == sellerId → แจ้ง buyer)
    - ทุก notification call ต้องอยู่ใน try-catch แยก — ถ้า notification ล้มเหลวให้ log error แต่ไม่ fail transaction response
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

  - [x] 3.2 เขียน property test สำหรับ Transaction Notification
    - **Property 2: Transaction State Transition สร้าง Notification**
    - ทดสอบว่าทุก state transition (confirm, ship, complete, cancel) สร้าง notification 1 รายการ โดย user_id เป็นอีกฝ่ายที่ไม่ใช่ผู้กระทำ
    - **Validates: Requirements 4.1, 4.2, 4.3, 4.4**

  - [x] 3.3 เขียน property test สำหรับ Notification Failure Isolation
    - **Property 3: Notification Failure ไม่ทำให้ Operation หลักล้มเหลว**
    - ทดสอบว่าถ้า notificationService.createNotification throw error, transaction response ยังคง HTTP 2xx
    - **Validates: Requirements 4.5, 5.3**

- [x] 4. Wire Notification ใน Chat Controller
  - [x] 4.1 แก้ `backend/services/chat.service.js` ให้ `sendMessage()` return room info (buyer_id, seller_id) กลับมาด้วย
    - ปัจจุบัน `sendMessage()` query room data อยู่แล้ว (ตัวแปร `room`) แต่ไม่ได้ return กลับ — แก้ให้ return `room` ใน result object ด้วย
    - _Requirements: 5.2_

  - [x] 4.2 เพิ่ม notification call ใน `backend/controllers/chat.controller.js` function `sendMessage()`
    - Import `notificationService` จาก `../services/notification.service`
    - หลังจาก `chatService.sendMessage()` สำเร็จ ให้ดึง room info จาก result
    - หา recipientId: ถ้า senderId == room.buyer_id → recipientId = room.seller_id, และกลับกัน
    - เรียก `notificationService.createNotification(recipientId, 'chat_message', 'ข้อความใหม่', content?.substring(0, 100) || 'ส่งรูปภาพ', { roomId })`
    - ใส่ใน try-catch แยก — ถ้า notification ล้มเหลวให้ log error แต่ไม่ fail message response
    - _Requirements: 5.1, 5.2, 5.3_

  - [x] 4.3 เขียน property test สำหรับ Chat Notification
    - **Property 4: Chat Message สร้าง Notification ไปยังผู้รับที่ถูกต้อง**
    - ทดสอบว่าทุกข้อความที่ส่งสำเร็จ สร้าง notification 1 รายการ โดย user_id เป็นฝ่ายที่ไม่ใช่ผู้ส่ง
    - **Validates: Requirements 5.1, 5.2**

- [x] 5. Checkpoint — ตรวจสอบ Notification Wiring
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. แก้ไข Bug: NotificationService Field Name Mismatch (Flutter)
  - [x] 6.1 แก้ `frontend/lib/services/notification_service.dart` method `getUnreadCount()`
    - เปลี่ยน `data['count']` เป็น `data['unreadCount']` ให้ตรงกับ backend response `{ "unreadCount": N }`
    - _Requirements: 8.1, 8.2_

- [x] 7. แก้ไข Bug: TransactionService Response Format Mismatch (Flutter)
  - [x] 7.1 แก้ `frontend/lib/services/transaction_service.dart` method `getUserTransactions()`
    - เปลี่ยนจาก parse เป็น `List` ตรงๆ เป็น parse grouped object `{ "processing": [...], "shipping": [...], "history": [...], "canceled": [...] }`
    - Return type เปลี่ยนจาก `Future<List<Transaction>>` เป็น `Future<Map<String, List<Transaction>>>`
    - เพิ่ม error handling สำหรับ response format ที่ไม่คาดหวัง
    - _Requirements: 9.1, 9.2, 9.3_

  - [x] 7.2 แก้ `frontend/lib/screens/transaction_list_screen.dart` ให้รองรับ grouped data
    - เปลี่ยนจากการเก็บ `_allTransactions` เป็น `List<Transaction>` แล้ว filter เอง → เป็นการรับ `Map<String, List<Transaction>>` จาก service แล้วใช้ key ตรงๆ ในแต่ละ tab
    - _Requirements: 9.2_

- [x] 8. แก้ไข HomePage ให้ดึงสินค้าจาก API จริง
  - [x] 8.1 แก้ `frontend/lib/screens/home_screen.dart` ให้ส่ง products และ state ไปยัง HomePage
    - ปัจจุบัน `_fetchProducts()` ดึงข้อมูลแล้วเก็บใน `products` แต่ `build()` return `const HomePage()` โดยไม่ส่ง products
    - แก้ให้ส่ง `products`, `isLoading`, และ callback `onRetry` เป็น parameter ไปยัง `HomePage`
    - _Requirements: 6.1, 6.3, 6.4, 6.5_

  - [x] 8.2 แก้ `frontend/lib/pages/home_page.dart` ให้รับ products จาก parameter แทน kAllProducts
    - เพิ่ม constructor parameters: `List<Product> products`, `bool isLoading`, `VoidCallback? onRetry`, `String currentUserId`
    - แก้ `_buildTrendingList()` ให้ใช้ `widget.products` แทน `kAllProducts`
    - เพิ่ม loading indicator เมื่อ `isLoading == true`
    - เพิ่ม error/empty state พร้อมปุ่ม retry เมื่อ products ว่าง
    - แก้ `_buildProductCard()` ให้รับ `Product` (จาก API) แทน `ProductItem` (hardcoded) — แสดง title, price, images, category
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

  - [x] 8.3 เขียน property test สำหรับ HomePage กรองสินค้าของตัวเอง
    - **Property 5: HomePage กรองสินค้าของตัวเองออก**
    - ทดสอบว่าทุก product ที่แสดงบน HomePage มี ownerId ≠ currentUserId
    - **Validates: Requirements 6.5**

- [x] 9. แก้ไข Navigation ใน HomePage Bottom Nav
  - [x] 9.1 Wire navigation ใน `frontend/lib/pages/home_page.dart` bottom nav
    - ปุ่ม "Sell": `Navigator.push` → `AddProductScreen` (ต้อง import `add_product_screen.dart` และส่ง `currentUserId`)
    - ปุ่ม "Chat": `Navigator.push` → `ChatListScreen` (ต้อง import `chat_list_screen.dart` และส่ง `userId`)
    - ปุ่ม "Profile": `Navigator.push` → `UserProfileScreen` หรือ `TransactionListScreen` (ส่ง `userId`)
    - _Requirements: 7.1, 7.2, 7.3_

- [x] 10. แก้ไขหน้า Favourited ให้ทำงานกับข้อมูลจริง
  - [x] 10.1 แก้ `frontend/lib/pages/favourite_manager.dart` ให้ `favouritedProducts` ดึงข้อมูลจาก API
    - ปัจจุบัน `favouritedProducts` getter filter จาก `kAllProducts` (hardcoded) — แก้ให้ดึง product details จาก API โดยใช้ product IDs ที่อยู่ใน `_myFavourites`
    - เพิ่ม method `fetchFavouritedProducts()` ที่เรียก product API เพื่อดึงข้อมูลสินค้าจริง
    - ใช้ `currentUserId` จาก auth แทน random generated `_userId`
    - _Requirements: 10.1, 10.2, 10.3_

  - [x] 10.2 แก้ `frontend/lib/pages/favourited_page.dart` ให้แสดง `Product` (จาก API) แทน `ProductItem`
    - เปลี่ยน `_buildFavCard()` ให้รับ `Product` แทน `ProductItem`
    - แสดง product image จาก network URL แทน asset path
    - _Requirements: 10.3_

  - [x] 10.3 เขียน property test สำหรับ Favourite Toggle
    - **Property 8: Favourite Toggle Round-Trip**
    - ทดสอบว่า toggle favourite แล้ว สถานะใน product_favourites table ตรงกับ local state
    - **Validates: Requirements 10.2**

- [x] 11. Final Checkpoint — ตรวจสอบทุกอย่างทำงานร่วมกัน
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks ที่มี `*` เป็น optional (property tests / unit tests) สามารถข้ามได้เพื่อ MVP ที่เร็วขึ้น
- ทุก task อ้างอิง requirements เฉพาะเพื่อ traceability
- Checkpoints ช่วยตรวจสอบความถูกต้องแบบ incremental
- Backend ใช้ JavaScript (Node.js/Express + Prisma), Frontend ใช้ Dart (Flutter)
- Property tests ใช้ fast-check library สำหรับ backend
