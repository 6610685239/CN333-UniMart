<div align="center">

<img src="https://readme-typing-svg.demolab.com?font=Fira+Code&size=28&duration=2500&pause=800&color=FF6B35&center=true&vCenter=true&width=900&lines=CN333+UniMart;Second-hand+Marketplace+for+TU+Students;Buy+%E2%80%A2+Sell+%E2%80%A2+Rent+%E2%80%94+Verified+by+TU+API" alt="Typing SVG" />

<br/>

A **Verified Second-hand Marketplace** exclusively for Thammasat University students. 
Buy, Sell, and Rent items within the university — authenticated via **TU RESTful API**.

<br/>

[![Flutter](https://img.shields.io/badge/Flutter-3.8.1-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![Node.js](https://img.shields.io/badge/Node.js-Express_5.2-339933?style=flat-square&logo=nodedotjs&logoColor=white)](https://nodejs.org)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Supabase-316192?style=flat-square&logo=postgresql&logoColor=white)](https://supabase.com)
[![Socket.IO](https://img.shields.io/badge/Socket.IO-4.8-010101?style=flat-square&logo=socketdotio&logoColor=white)](https://socket.io)
[![Prisma](https://img.shields.io/badge/Prisma-6.19-2D3748?style=flat-square&logo=prisma&logoColor=white)](https://prisma.io)
[![License](https://img.shields.io/badge/License-Educational-orange?style=flat-square)](./LICENSE)
[![Status](https://img.shields.io/badge/Status-In_Development-brightgreen?style=flat-square)]()

</div>

---

## Overview

**UniMart** คือแอปพลิเคชัน Marketplace สำหรับนักศึกษามหาวิทยาลัยธรรมศาสตร์ ออกแบบมาเพื่อให้การ **ซื้อ-ขาย-เช่า** สินค้ามือสองในมหาวิทยาลัยเป็นเรื่องง่าย ปลอดภัย และน่าเชื่อถือ โดยผู้ใช้ทุกคนต้องยืนยันตัวตนผ่าน **TU RESTful API** ก่อนเข้าใช้งาน

---

## Tech Stack

<div align="center">

| Layer | Technology |
|:---:|:---:|
| ![Flutter](https://img.shields.io/badge/Frontend-Flutter_(Dart_^3.8.1)-02569B?style=for-the-badge&logo=flutter&logoColor=white) | Mobile & Web Application |
| ![Node.js](https://img.shields.io/badge/Backend-Node.js_+_Express_5.2-339933?style=for-the-badge&logo=nodedotjs&logoColor=white) | REST API Server |
| ![PostgreSQL](https://img.shields.io/badge/Database-PostgreSQL_(Supabase)-316192?style=for-the-badge&logo=postgresql&logoColor=white) | Relational Database |
| ![Prisma](https://img.shields.io/badge/ORM-Prisma_6.19-2D3748?style=for-the-badge&logo=prisma&logoColor=white) | Database ORM |
| ![Socket.IO](https://img.shields.io/badge/Realtime-Socket.IO_4.8-010101?style=for-the-badge&logo=socketdotio&logoColor=white) | Real-time Chat |
| ![JWT](https://img.shields.io/badge/Auth-JWT_+_bcrypt_+_TU_API-000000?style=for-the-badge&logo=jsonwebtokens&logoColor=white) | Authentication |
| ![Jest](https://img.shields.io/badge/Testing-Jest_+_fast--check-C21325?style=for-the-badge&logo=jest&logoColor=white) | Property-based Testing |

</div>

---

## Key Features

### Authentication
- ยืนยันตัวตนผ่าน **TU RESTful API** (`reg.tu.ac.th`) — เฉพาะนักศึกษา/บุคลากรธรรมศาสตร์เท่านั้น
- ลงทะเบียนด้วยรหัสผ่าน UniMart แยกอิสระจากรหัสผ่าน TU
- **JWT-based Session** (30 วัน) + เปลี่ยนรหัสผ่านได้

### Product Management
- ลงขาย/ให้เช่าสินค้า พร้อมอัปโหลดรูปสูงสุด **5 รูป**
- ระบบ **Quantity/Stock** รองรับสินค้าหลายชิ้นในโพสต์เดียว
- **9 หมวดหมู่:** เสื้อผ้า, อิเล็กทรอนิกส์, หนังสือ, กีฬา, เครื่องเขียน และอื่นๆ
- ค้นหาและกรองตาม: หมวดหมู่, ราคา, สภาพ, ประเภท (ขาย/เช่า), สถานะ, จุดนัดพบ

### Homepage
- **Trending Now ** — เรียงตาม Favourites
- **Recently Added ** — สินค้าลงขายล่าสุด
- หมวดหมู่แบบ Horizontal Scroll
- กดหัวใจ บันทึกสินค้าที่สนใจ

### Real-time Chat
- แชทระหว่างผู้ซื้อ-ผู้ขายผ่าน **Socket.IO**
- รองรับข้อความ Text + รูปภาพ
- ปักหมุด (Pin) ห้องแชทสำคัญ
- **Read Receipts** (อ่านแล้ว/ยังไม่อ่าน)
- รายงานห้องแชทที่ไม่เหมาะสม

### Transaction System
- สถานะธุรกรรม: `PENDING` → `PROCESSING` → `SHIPPING` → `COMPLETED`
- ยกเลิกธุรกรรมได้ พร้อม **Auto Stock Restore**
- จำนวนสินค้าลดอัตโนมัติเมื่อซื้อ — หมดแล้วหยุดขายทันที
- ระบุ **Meeting Point** ภายในมหาวิทยาลัย

### ⭐ Review & Credit Score
- รีวิวผู้ซื้อ/ผู้ขายหลัง Transaction เสร็จสมบูรณ์ (1-5 ดาว)
- **Credit Score** เฉลี่ยแสดงในโปรไฟล์

### Notifications
- แจ้งเตือนสำหรับ Transaction และข้อความใหม่
- จัดการ Unread Count

---

## Project Structure

```
CN333-UniMart/
├── backend/ # Node.js API Server
│ ├── server.js # Express + Socket.IO entry point
│ ├── controllers/ # Request handlers (auth, chat, product, etc.)
│ ├── services/ # Business logic layer
│ ├── routes/ # API route definitions
│ ├── models/ # Prisma client & Supabase init
│ ├── prisma/
│ │ ├── schema.prisma # Database schema
│ │ └── seed.js # Seed data (categories, meeting points)
│ ├── tests/ # Jest + Property-based tests
│ └── uploads/ # Uploaded image storage
│
└── frontend/ # Flutter Mobile/Web App
 ├── lib/
 │ ├── main.dart # App entry point & routing
 │ ├── config.dart # API base URL configuration
 │ ├── models/ # Data models (Product, Category, etc.)
 │ ├── screens/ # 19 UI screens
 │ ├── pages/ # Home page, Favourite manager
 │ └── services/ # API, Auth, Chat, Review services
 └── assets/
 ├── fonts/ # NotoSansThai font
 └── images/ # App assets
```

---

## Database Schema

<details>
<summary><b> Click to expand schema details</b></summary>

### `users`
| Field | Type | Description |
|---|---|---|
| `id` | UUID | Primary Key |
| `username` | String | รหัสนักศึกษา (unique) |
| `display_name_th` | String? | ชื่อ-นามสกุล (ภาษาไทย) |
| `display_name_en` | String? | ชื่อ-นามสกุล (English) |
| `faculty` | String? | คณะ |
| `department` | String? | ภาควิชา |
| `tu_status` | String? | สถานะนักศึกษา |
| `avatar` | String? | รูปโปรไฟล์ (filename) |
| `password_hash` | String? | รหัสผ่าน UniMart (bcrypt) |
| `dormitory_zone` | String? | โซนหอพัก |

### `Product`
| Field | Type | Description |
|---|---|---|
| `id` | Int | Primary Key |
| `title` | String | ชื่อสินค้า |
| `description` | String | รายละเอียด |
| `price` | Int | ราคาขาย (บาท) |
| `images` | String[] | รูปสินค้า (สูงสุด 5 รูป) |
| `condition` | String | สภาพ (มือหนึ่ง/มือสอง) |
| `type` | String | ประเภท (SALE/RENT) |
| `rentPrice` | Int? | ราคาเช่า/วัน |
| `quantity` | Int | จำนวนคงเหลือ (default: 1) |
| `status` | String | AVAILABLE / RESERVED / SOLD |
| `location` | String | สถานที่ |
| `ownerId` | UUID | FK → users |
| `categoryId` | Int? | FK → Category |

### `Transaction`
| Field | Type | Description |
|---|---|---|
| `id` | Int | Primary Key |
| `buyerId` | UUID | FK → users (ผู้ซื้อ) |
| `sellerId` | UUID | FK → users (ผู้ขาย) |
| `productId` | Int | FK → Product |
| `type` | String | SALE / RENT |
| `status` | String | PENDING → PROCESSING → SHIPPING → COMPLETED |
| `price` | Int | ราคาที่ตกลง |

</details>

---

## API Endpoints

<details>
<summary><b> Click to expand API reference</b></summary>

### Authentication — `/api/auth`
| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/verify` | ยืนยันตัวตน TU API |
| `POST` | `/register` | ลงทะเบียน |
| `POST` | `/login` | เข้าสู่ระบบ |
| `POST` | `/change-password` | เปลี่ยนรหัสผ่าน |
| `POST` | `/:userId/avatar` | อัปโหลดรูปโปรไฟล์ |
| `GET` | `/:userId/profile` | ดูโปรไฟล์ผู้ใช้ |

### Products — `/api`
| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/categories` | ดึงหมวดหมู่ทั้งหมด |
| `GET` | `/products` | ดึงสินค้าทั้งหมด |
| `GET` | `/products/:id` | ดึงสินค้าตาม ID |
| `POST` | `/products` | สร้างสินค้า (multipart) |
| `PATCH` | `/products/:id` | แก้ไขสินค้า |
| `DELETE` | `/products/:id` | ลบสินค้า |
| `GET` | `/products/filter` | กรองสินค้า |

### Chat — `/api/chat`
| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/rooms` | สร้างห้องแชท |
| `GET` | `/rooms/:userId` | ดึงห้องแชทของผู้ใช้ |
| `POST` | `/messages` | ส่งข้อความ |
| `GET` | `/rooms/:roomId/messages` | ดึงประวัติข้อความ |

### Transactions — `/api/transactions`
| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/` | สร้างธุรกรรม |
| `PATCH` | `/:id/confirm` | ผู้ขายยืนยัน |
| `PATCH` | `/:id/ship` | อัปเดตสถานะจัดส่ง |
| `PATCH` | `/:id/complete` | ปิดธุรกรรม |
| `PATCH` | `/:id/cancel` | ยกเลิก |
| `GET` | `/user/:userId` | ดึงธุรกรรมของผู้ใช้ |

### Reviews — `/api/reviews`
| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/` | สร้างรีวิว |
| `GET` | `/user/:userId` | ดึงรีวิวผู้ใช้ |
| `GET` | `/credit/:userId` | ดึง Credit Score |

</details>

---

## Getting Started

### Prerequisites

```
Node.js ≥ 18 Flutter SDK ≥ 3.8.1 PostgreSQL (Supabase) TU API Key
```

### Backend Setup

```bash
cd backend

# Install dependencies
npm install

# Configure environment
cp .env.example .env

# Setup database
npx prisma generate
npx prisma db push
npx prisma db seed

# Start server
node server.js
```

### Backend Environment Variables (`.env`)

```env
DATABASE_URL=postgresql://... # Prisma connection string (pooled)
DIRECT_URL=postgresql://... # Direct connection (migrations)
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_KEY=eyJ...
JWT_SECRET=your-secret-key
TU_API_KEY=your-tu-api-key
PORT=3000
```

### Frontend Setup

```bash
cd frontend

flutter pub get
flutter run
```

### Frontend Environment Variables (`.env`)

```env
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_ANON_KEY=eyJ...
```

---

## Testing

Backend ใช้ **Jest** + **fast-check** (Property-based Testing) + **Supertest**

```bash
cd backend

npm test

# Run specific test
npx jest tests/auth.property.test.js --forceExit
npx jest tests/transaction.property.test.js --forceExit
```

<details>
<summary><b> Test Coverage</b></summary>

| Module | Test Files |
|---|---|
| Auth | `auth.property.test.js` |
| Chat | `chat.property.test.js`, `chat.rooms.test.js`, `chat.messages.*.test.js`, `chat.reports.test.js` |
| Transaction | `transaction.property.test.js`, `transactions.create.test.js`, `transactions.state.test.js` |
| Review | `review.property.test.js`, `reviews.test.js` |
| Filter | `filter.property.test.js`, `homepage.filter.property.test.js`, `smart-filter.test.js` |
| Notification | `notification.property.test.js`, `notification.failure.property.test.js`, `notifications.test.js` |
| Favourites | `favourite.toggle.property.test.js` |
| Seed | `seed.property.test.js` |

</details>

---

## Team

<div align="center">

| Student ID | Name | Role |
|:---:|:---|:---|
| **661068XXXX** | — | — |
| **661068XXXX** | — | — |

</div>

---

<div align="center">

**Course:** CN333 Mobile & Web Application Development &nbsp;·&nbsp; **Thammasat University** &nbsp;·&nbsp; Semester 2/2568

*This project is developed for educational purposes as part of CN333 coursework.*

</div>
