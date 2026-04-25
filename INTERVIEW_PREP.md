# CN333-UniMart Interview Prep

## 1-Page Interview Cheat Sheet

### Project Overview
`CN333-UniMart` is a full-stack marketplace application designed for a university community. The main goal is to help students buy, sell, or rent items such as textbooks, gadgets, uniforms, and dormitory-related goods within a trusted campus ecosystem.

### Problem It Solves
Many students need a simple and reliable way to exchange second-hand goods within the university. Existing public marketplaces are too broad and less contextual for campus use. This project solves that by focusing on student needs, nearby transactions, and trust-building features.

### Core Features
- User authentication
- Product listing and browsing
- Product categories and filters
- Favourite products
- Buyer-seller transactions
- Product reviews
- In-app notifications
- Real-time chat between users

### Tech Stack
#### Backend
- Node.js
- Express
- Prisma
- PostgreSQL
- Supabase
- Socket.io
- Jest
- fast-check
- Multer
- JWT + bcrypt

#### Frontend
- Flutter
- supabase_flutter
- flutter_dotenv
- socket_io_client
- http
- shared_preferences

### Architecture Summary
The system is split into two major parts:
- `backend/`: provides REST APIs, business logic, database access, notifications, and real-time communication
- `frontend/`: Flutter client that consumes APIs and handles UI/UX across platforms

Backend is organized into:
- `routes/` for endpoint definitions
- `controllers/` for request/response handling
- `services/` for business logic
- `prisma/` for schema and seed data

Frontend is organized into:
- `screens/` for pages
- `services/` for API communication
- `models/` for data structures
- `pages/` for shared logic/components

### Database / Domain Model
Important entities include:
- `users`
- `Product`
- `Transaction`
- `Review`
- `MeetingPoint`
- `product_favourites`

This supports a realistic marketplace workflow:
- a user posts a product
- another user initiates a purchase or rental
- both parties communicate through chat
- the transaction status is updated
- users can leave reviews after completion

### Real-Time System
Real-time messaging is implemented with Socket.io.
Key behaviors include:
- joining a chat room with `join_room`
- joining a per-user channel with `join_user`
- sending/receiving `new_message`
- marking messages as read with `mark_as_read`

This design supports both room-based messaging and targeted user updates.

### Engineering Strengths of the Project
- Full-stack integration across mobile/web client and backend APIs
- Real-world business flow beyond simple CRUD
- Separation of concerns with layered architecture
- Realtime communication support
- Automated testing including property-based tests
- Extensible structure for future features like push notifications

### Challenges You Can Talk About
- Keeping chat messages synchronized correctly in real time
- Handling transaction states reliably
- Connecting frontend, backend, and data model into one consistent flow
- Avoiding duplicate socket events and frontend race conditions
- Managing environment configuration safely at startup

### What I Contributed / Can Say I Worked On
You can adapt this depending on your actual involvement:

> I worked on analyzing and improving the end-to-end behavior of the application, especially around the chat and integration flow. I investigated backend query behavior, real-time event delivery, frontend socket handling, and runtime stability. I also reviewed automated tests and used them to validate fixes.

Short version:
- Debugged chat message loading issues
- Improved real-time delivery flow
- Reduced unnecessary socket room joins
- Helped verify backend behavior with tests
- Improved app startup resilience around environment configuration

### What I Learned
- How to design and debug a full-stack application with multiple business flows
- How to connect REST APIs with realtime events
- How to model marketplace workflows with transactions and reviews
- How automated tests help catch edge cases early
- How to diagnose issues across frontend, backend, and data layers together

---

## Mock Interview Q&A (Thai)

### 1) โปรเจคนี้คืออะไร
โปรเจคนี้คือ `CN333-UniMart` เป็น marketplace application สำหรับนักศึกษาในมหาวิทยาลัย ใช้สำหรับซื้อ ขาย หรือปล่อยเช่าสินค้าภายใน community เช่น หนังสือเรียน อุปกรณ์การเรียน หรือของใช้ต่าง ๆ โดยมีฟีเจอร์หลัก เช่น ระบบสินค้า ธุรกรรม รีวิว การแจ้งเตือน และแชทแบบ realtime

### 2) จุดประสงค์ของโปรเจคนี้คืออะไร
จุดประสงค์คือแก้ปัญหาการซื้อขายของมือสองหรือของใช้ภายในมหาวิทยาลัยให้สะดวกและน่าเชื่อถือขึ้น ผู้ใช้ไม่ต้องไปพึ่ง marketplace ทั่วไปที่ไม่เฉพาะกับบริบทของนักศึกษา

### 3) ใช้เทคโนโลยีอะไรบ้าง
ฝั่ง backend ใช้ Node.js, Express, Prisma, PostgreSQL, Supabase, Socket.io และ Jest ส่วน frontend ใช้ Flutter พร้อมแพ็กเกจอย่าง `supabase_flutter`, `flutter_dotenv` และ `socket_io_client`

### 4) โครงสร้างระบบเป็นอย่างไร
ระบบแบ่งเป็น 2 ส่วน คือ backend กับ frontend โดย backend ดูแล API, business logic, database และ realtime events ส่วน frontend ดูแล UI และการเรียกใช้งาน API/Socket ในเชิงสถาปัตยกรรม backend แยกเป็น `routes`, `controllers`, `services` เพื่อให้ maintain และ test ได้ง่าย

### 5) ฟีเจอร์ที่สำคัญที่สุดคืออะไร
ฟีเจอร์สำคัญคือการจัดการสินค้า ระบบธุรกรรม และระบบแชทแบบ realtime เพราะเป็นแกนหลักของ user journey ตั้งแต่เริ่มสนใจสินค้า ติดต่อคู่ซื้อขาย จนจบที่ transaction และ review

### 6) ทำไมถึงเลือก Flutter
Flutter ช่วยให้ใช้ codebase เดียวรองรับหลายแพลตฟอร์ม และพัฒนา UI ได้รวดเร็ว เหมาะกับโปรเจคที่ต้องการทั้งความเร็วในการพัฒนาและการแสดงผลที่สม่ำเสมอ

### 7) ทำไมถึงใช้ Socket.io
เพราะระบบแชทต้องการ realtime communication ถ้าใช้ polling จะไม่เหมาะทั้งในแง่ latency และประสบการณ์ผู้ใช้ Socket.io ทำให้จัดการ event ต่าง ๆ เช่นเข้าห้อง แสดงข้อความใหม่ และอัปเดตสถานะการอ่านได้สะดวก

### 8) โครงสร้างฐานข้อมูลออกแบบยังไง
ฐานข้อมูลมี entity หลักอย่าง `users`, `Product`, `Transaction`, `Review`, `MeetingPoint` และ `product_favourites` ซึ่งรองรับ workflow จริงของ marketplace เช่น ผู้ใช้ลงสินค้า มีผู้ซื้อทำรายการ ซื้อ/เช่า มีการคุยกันในแชท และให้รีวิวหลังจบธุรกรรม

### 9) ความท้าทายของโปรเจคนี้คืออะไร
ความท้าทายคือการเชื่อมหลายระบบเข้าด้วยกันให้ข้อมูลสอดคล้องกัน เช่น product, transaction, review, notification และ chat โดยเฉพาะส่วน realtime ที่ต้องทั้งเร็วและถูกต้อง รวมถึงการจัดการ edge cases ของ business logic

### 10) คุณมีส่วนช่วยในโปรเจคนี้อย่างไร
ผมช่วยในส่วนการวิเคราะห์และแก้ปัญหาเชิง end-to-end โดยเฉพาะ flow ของแชทและการเชื่อม frontend-backend เช่น ตรวจ logic การดึงข้อความ, การทำงานของ socket, การลด event ที่ซ้ำซ้อน และการยืนยันผลผ่าน automated tests

### 11) คุณแก้ปัญหาอะไรที่น่าสนใจบ้าง
ตัวอย่างหนึ่งคือปัญหาข้อความใหม่ในแชทไม่แสดงครบตามที่ควร เพราะ query ฝั่ง backend ดึงข้อมูลไม่ตรงกับการใช้งานจริงของ UI ผมจึงวิเคราะห์ root cause แล้วปรับ logic การดึงข้อความและ flow ของ realtime event ให้สอดคล้องกันมากขึ้น

### 12) ได้เรียนรู้อะไรจากโปรเจคนี้
ได้เรียนรู้การทำ full-stack application แบบมี business flow จริง ไม่ใช่แค่ CRUD ทั่วไป รวมถึงการวิเคราะห์ปัญหาข้ามหลาย layer ตั้งแต่ UI, API, socket event ไปจนถึง data model และการใช้ tests เพื่อช่วยยืนยันว่าปัญหาถูกแก้จริง

### 13) ถ้าพัฒนาต่อจะเพิ่มอะไร
ผมจะเพิ่ม push notifications ด้วย FCM, เพิ่ม integration/end-to-end tests, ปรับ transaction workflow ให้แข็งแรงขึ้น, เพิ่ม monitoring/logging และปรับ performance ของการดึงข้อมูล เช่น pagination และ caching

### 14) จุดแข็งของโปรเจคนี้คืออะไร
จุดแข็งคือเป็นโปรเจคที่มี business flow ครบ, มี realtime feature, มี layered architecture และสะท้อนโจทย์จริงของระบบ marketplace ได้ดี

### 15) จุดแข็งของคุณจากโปรเจคนี้คืออะไร
จุดแข็งของผมคือสามารถมองปัญหาแบบ end-to-end ได้ เห็นความเชื่อมโยงระหว่าง frontend, backend และ data flow และใช้การวิเคราะห์เชิงระบบร่วมกับ automated tests เพื่อหา root cause และแก้ปัญหาได้เป็นขั้นตอน

---

## Mock Interview Q&A (English)

### 1) What is this project about?
This project, `CN333-UniMart`, is a marketplace application for a university community. It allows students to buy, sell, or rent items such as textbooks, gadgets, and daily-use goods within a more trusted campus-focused environment.

### 2) What problem does it solve?
It solves the problem of student-to-student trading in a more contextual and convenient way. General marketplaces are too broad, while this app focuses on local university use cases and trust-oriented interactions.

### 3) What technologies did you use?
The backend uses Node.js, Express, Prisma, PostgreSQL, Supabase, Socket.io, and Jest. The frontend is built with Flutter and uses packages such as `supabase_flutter`, `flutter_dotenv`, and `socket_io_client`.

### 4) How is the system structured?
The system is split into backend and frontend. The backend handles APIs, business logic, database access, and realtime communication. The frontend handles UI and client-side interaction. On the backend, the project follows a layered structure with routes, controllers, and services.

### 5) What are the key features?
The key features include product listings, favourites, transactions, reviews, notifications, and real-time chat between buyers and sellers.

### 6) Why did you choose Flutter?
Flutter allows a single codebase for multiple platforms and supports fast UI development, which made it a good fit for this kind of application.

### 7) Why did you use Socket.io?
The chat system requires real-time communication. Socket.io is suitable for event-driven interactions such as joining rooms, receiving new messages, and updating read status.

### 8) What was the most challenging part?
One of the biggest challenges was making sure multiple business flows worked together consistently, especially chat, transaction status updates, notifications, and the frontend-backend integration.

### 9) What was your contribution?
I contributed by analyzing and improving the end-to-end behavior of the application, especially around the chat flow, backend query behavior, real-time event delivery, frontend socket handling, and runtime stability. I also used tests to validate fixes.

### 10) What did you learn from this project?
I learned how to build and debug a full-stack application with real business workflows, how to connect REST APIs with realtime communication, and how to diagnose issues across frontend, backend, and data layers together.

---

## Quick Self-Introduction Version

### Thai
โปรเจคที่ผมภูมิใจคือ `CN333-UniMart` ซึ่งเป็น marketplace app สำหรับนักศึกษาในมหาวิทยาลัยครับ ผมได้ทำงานกับทั้งฝั่งระบบและการเชื่อมต่อระหว่าง frontend กับ backend โดยเฉพาะในส่วน chat realtime, business flow ของ marketplace และการใช้ automated tests เพื่อช่วยยืนยันความถูกต้องของระบบ จุดที่ผมได้เรียนรู้มากที่สุดคือการแก้ปัญหาแบบ end-to-end และการทำให้หลายระบบทำงานร่วมกันได้อย่างมีเสถียรภาพ

### English
One project I am proud of is `CN333-UniMart`, a marketplace app for university students. I worked on the system integration between frontend and backend, especially around real-time chat, marketplace workflows, and using automated tests to validate behavior. The biggest thing I learned was how to debug problems end-to-end and make multiple parts of a system work together reliably.

---

## Tips for Interview Delivery
- Explain the business goal before the tech stack
- Mention real problems and how you solved them
- Focus on your reasoning, not only the tools
- Use terms like: full-stack, business logic, realtime communication, architecture, testing, root cause analysis
- If asked something very deep, answer with what you know from the design and implementation rather than guessing
