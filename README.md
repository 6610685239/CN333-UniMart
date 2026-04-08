# CN333-UniMart 🏪

> **Second-hand Marketplace for Thammasat University Students**  
> วิชา CN333 – Mobile & Web Application Development

UniMart เป็นแอปพลิเคชัน Marketplace สำหรับนักศึกษามหาวิทยาลัยธรรมศาสตร์ ใช้สำหรับ **ซื้อ-ขาย-เช่า** สินค้ามือสองภายในมหาวิทยาลัย โดยยืนยันตัวตนผ่านระบบ TU API เพื่อให้แน่ใจว่าผู้ใช้ทุกคนเป็นนักศึกษาหรือบุคลากรของธรรมศาสตร์

---

## ✨ Features

### 🔐 Authentication
- ยืนยันตัวตนผ่าน **TU RESTful API** (reg.tu.ac.th)
- ลงทะเบียนด้วยรหัสผ่าน UniMart (แยกจากรหัสผ่าน TU)
- JWT-based session management (30 วัน)
- เปลี่ยนรหัสผ่าน UniMart ได้

### 🛍️ Product Management
- ลงขาย/ให้เช่าสินค้า พร้อมอัปโหลดรูปสูงสุด **5 รูป**
- ระบบ **จำนวนสินค้า (Quantity/Stock)** — รองรับขายหลายชิ้น
- 9 หมวดหมู่สินค้า: เสื้อผ้า, อิเล็กทรอนิกส์, หนังสือ, กีฬา, เครื่องเขียน ฯลฯ
- ค้นหาและกรองสินค้าตาม: หมวดหมู่, ราคา, สภาพ, ประเภท (ขาย/เช่า), สถานะ, จุดนัดพบ

### 🏠 Homepage
- **Trending Now 🔥** — สินค้ายอดนิยมเรียงตาม Favourites
- **Recently Add ✨** — สินค้าลงขายล่าสุด
- หมวดหมู่สินค้าแบบ Horizontal Scroll
- กดหัวใจ ❤️ เพื่อบันทึกสินค้าที่สนใจ

### 💬 Real-time Chat (Socket.IO)
- แชทระหว่างผู้ซื้อ-ผู้ขายแบบ Real-time
- ส่งข้อความ Text, รูปภาพ
- ปักหมุด (Pin) ห้องแชทที่สำคัญ
- อ่านแล้ว/ยังไม่อ่าน (Read receipts)
- รายงานห้องแชทที่ไม่เหมาะสม

### 💰 Transaction System
- สถานะธุรกรรม: `PENDING` → `PROCESSING` → `SHIPPING` → `COMPLETED`
- ยกเลิกธุรกรรมได้ (คืน Stock อัตโนมัติ)
- เมื่อซื้อสินค้า จำนวนลดลงอัตโนมัติ, หมด = หยุดขาย
- ระบุจุดนัดพบ (Meeting Point) ภายในมหาวิทยาลัย

### ⭐ Review & Credit Score
- รีวิวผู้ซื้อ/ผู้ขายหลังทำธุรกรรมสำเร็จ (1-5 ดาว)
- คะแนนเฉลี่ย Credit Score แสดงในโปรไฟล์

### 🔔 Notifications
- การแจ้งเตือนสำหรับธุรกรรม, แชท
- จัดการ Unread Count

### 👤 User Profiles
- โปรไฟล์ส่วนตัว: ร้านค้า, ธุรกรรม, ตั้งค่า
- โปรไฟล์ผู้ขาย (Read-only): ดูข้อมูลผู้ขาย, Credit Score, สินค้า

---

## 🏗️ Tech Stack

| Layer | Technology |
|---|---|
| **Frontend** | Flutter (Dart SDK ^3.8.1) |
| **Backend** | Node.js + Express 5.2.1 |
| **Database** | PostgreSQL (Supabase) |
| **ORM** | Prisma 6.19 |
| **Real-time** | Socket.IO 4.8 |
| **Auth** | JWT + bcrypt + TU RESTful API |
| **File Upload** | Multer 2.0 (Disk Storage) |
| **State Management** | StatefulWidget + SharedPreferences |

---

## 📁 Project Structure

```
CN333-UniMart/
├── backend/                    # Node.js API Server
│   ├── server.js               # Express + Socket.IO entry point
│   ├── controllers/            # Request handlers
│   │   ├── auth.controller.js
│   │   ├── chat.controller.js
│   │   ├── filter.controller.js
│   │   ├── notification.controller.js
│   │   ├── product.controller.js
│   │   ├── review.controller.js
│   │   └── transaction.controller.js
│   ├── services/               # Business logic
│   │   ├── auth.service.js
│   │   ├── chat.service.js
│   │   ├── filter.service.js
│   │   ├── notification.service.js
│   │   ├── product.service.js
│   │   ├── review.service.js
│   │   └── transaction.service.js
│   ├── routes/                 # API route definitions
│   ├── models/                 # Prisma client & Supabase init
│   ├── prisma/                 # Schema & seed data
│   │   ├── schema.prisma
│   │   └── seed.js
│   ├── tests/                  # Jest + Property-based tests
│   └── uploads/                # Uploaded images storage
│
├── frontend/                   # Flutter Mobile/Web App
│   ├── lib/
│   │   ├── main.dart           # App entry point & routing
│   │   ├── config.dart         # API base URL configuration
│   │   ├── models/             # Data models (Product, Category, etc.)
│   │   ├── screens/            # UI screens (19 screens)
│   │   ├── pages/              # Home page, Favourite manager
│   │   └── services/           # API, Auth, Chat, Review services
│   ├── assets/
│   │   ├── fonts/              # NotoSansThai font
│   │   └── images/             # App images
│   └── pubspec.yaml
│
└── README.md
```

---

## 📊 Database Schema

### `users`
ข้อมูลผู้ใช้จากระบบ TU + ข้อมูลเพิ่มเติมของ UniMart

| Field | Type | Description |
|---|---|---|
| `id` | UUID | Primary Key |
| `username` | String | รหัสนักศึกษา (unique) |
| `display_name_th` | String? | ชื่อ-นามสกุล (ภาษาไทย) |
| `display_name_en` | String? | ชื่อ-นามสกุล (English) |
| `faculty` | String? | คณะ |
| `department` | String? | ภาควิชา |
| `tu_status` | String? | สถานะนักศึกษา (ปกติ/ลาพัก ฯลฯ) |
| `avatar` | String? | รูปโปรไฟล์ (filename) |
| `password_hash` | String? | รหัสผ่าน UniMart (bcrypt) |
| `dormitory_zone` | String? | โซนหอพัก |

### `Product`
สินค้าที่ลงขาย/ให้เช่า

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
| `status` | String | สถานะ (AVAILABLE/RESERVED/SOLD) |
| `location` | String | สถานที่ |
| `ownerId` | UUID | FK → users |
| `categoryId` | Int? | FK → Category |

### `Transaction`
ธุรกรรมซื้อ-ขาย/เช่า

| Field | Type | Description |
|---|---|---|
| `id` | Int | Primary Key |
| `buyerId` | UUID | FK → users (ผู้ซื้อ) |
| `sellerId` | UUID | FK → users (ผู้ขาย) |
| `productId` | Int | FK → Product |
| `type` | String | SALE / RENT |
| `status` | String | PENDING → PROCESSING → SHIPPING → COMPLETED |
| `price` | Int | ราคาที่ตกลง |

### `Review`
รีวิวหลังทำธุรกรรม

### `Category`
9 หมวดหมู่สินค้า

### `MeetingPoint`
จุดนัดพบในมหาวิทยาลัย

---

## 🌐 API Endpoints

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
| `GET` | `/rooms/:userId` | ดึงห้องแชท |
| `POST` | `/messages` | ส่งข้อความ |
| `GET` | `/rooms/:roomId/messages` | ดึงข้อความ |

### Transactions — `/api/transactions`
| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/` | สร้างธุรกรรม |
| `PATCH` | `/:id/confirm` | ผู้ขายยืนยัน |
| `PATCH` | `/:id/ship` | จัดส่ง |
| `PATCH` | `/:id/complete` | เสร็จสิ้น |
| `PATCH` | `/:id/cancel` | ยกเลิก |
| `GET` | `/user/:userId` | ดึงธุรกรรมผู้ใช้ |

### Reviews — `/api/reviews`
| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/` | สร้างรีวิว |
| `GET` | `/user/:userId` | ดึงรีวิว |
| `GET` | `/credit/:userId` | ดึง Credit Score |

---

## 🚀 Getting Started

### Prerequisites
- **Node.js** ≥ 18
- **Flutter SDK** ≥ 3.8.1
- **PostgreSQL** (Supabase recommended)
- **TU API Key** (สำหรับยืนยันตัวตนนักศึกษา)

### Backend Setup

```bash
cd backend

# Install dependencies
npm install

# Configure environment variables
cp .env.example .env
# แก้ไข .env ตามค่าจริง

# Setup database
npx prisma generate
npx prisma db push

# Seed data (categories, meeting points)
npx prisma db seed

# Start server
node server.js
```

### Environment Variables (Backend `.env`)

```env
DATABASE_URL=postgresql://...         # Prisma connection string (pooled)
DIRECT_URL=postgresql://...           # Direct connection (for migrations)
SUPABASE_URL=https://xxx.supabase.co  # Supabase project URL
SUPABASE_KEY=eyJ...                   # Supabase anon/service key
JWT_SECRET=your-secret-key            # JWT signing secret
TU_API_KEY=your-tu-api-key            # TU RESTful API key
PORT=3000                             # Server port (default: 3000)
```

### Frontend Setup

```bash
cd frontend

# Configure environment variables
cp .env.example .env
# แก้ไข SUPABASE_URL และ SUPABASE_ANON_KEY

# Install dependencies
flutter pub get

# Run on device/emulator
flutter run
```

### Environment Variables (Frontend `.env`)

```env
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_ANON_KEY=eyJ...
```

---

## 🧪 Testing

Backend tests ใช้ **Jest** + **fast-check** (Property-based testing) + **Supertest**

```bash
cd backend

# Run all tests
npm test

# Run specific test
npx jest tests/auth.property.test.js --forceExit
npx jest tests/transaction.property.test.js --forceExit
```

### Test Coverage
| Module | Tests |
|---|---|
| Auth | `auth.property.test.js` |
| Chat | `chat.property.test.js`, `chat.rooms.test.js`, `chat.messages.*.test.js`, `chat.reports.test.js` |
| Transaction | `transaction.property.test.js`, `transactions.create.test.js`, `transactions.state.test.js` |
| Review | `review.property.test.js`, `reviews.test.js` |
| Filter | `filter.property.test.js`, `homepage.filter.property.test.js`, `smart-filter.test.js` |
| Notification | `notification.property.test.js`, `notification.failure.property.test.js`, `notifications.test.js` |
| Favourites | `favourite.toggle.property.test.js` |
| Seed | `seed.property.test.js` |

---

## 👥 Team

| Name | Student ID | Role |
|---|---|---|
| | | |

> **Course:** CN333 Mobile & Web Application Development  
> **University:** Thammasat University  
> **Semester:** 2/2568

---

## 📝 License

This project is developed for educational purposes as part of CN333 coursework at Thammasat University.
