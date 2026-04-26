<div align="center">

<img src="https://readme-typing-svg.demolab.com?font=JetBrains+Mono&weight=700&size=32&pause=1000&color=7B1A1A&center=true&vCenter=true&width=600&lines=UniMart;Second-Hand+Marketplace;Thammasat+University" alt="UniMart" />

**A second-hand marketplace exclusively for Thammasat University students.**
Buy, sell, and rent items within your campus — verified TU accounts only.

</div>

---

## Overview

UniMart is a full-stack marketplace application gated behind Thammasat University's RESTful API. Users must verify their TU credentials before registering a UniMart account, ensuring the platform is limited to real TU students.

---

## Tech Stack

### Frontend
- Flutter / Dart SDK ^3.8.1
- Supabase Flutter — storage and RLS-protected tables
- Socket.IO Client — real-time chat and notifications
- shared_preferences — JWT and favourites persistence
- Firebase Hosting

### Backend
- Node.js / Express 5
- Prisma ORM — PostgreSQL via Supabase connection pooler
- Socket.IO — real-time chat and notification events
- JWT (30-day) + bcrypt — authentication and password hashing
- Multer — file upload handling
- Jest + fast-check — property-based and integration testing
- Railway

### Database / Storage
- PostgreSQL on Supabase
- Supabase Storage — product images and avatars
- Supabase RLS — row-level security policies

---

## Architecture

```
Flutter → REST API (Express) → Prisma → PostgreSQL (Supabase)
Flutter ↔ Socket.IO (Express) — chat and notifications
Flutter → Supabase SDK (direct) — RLS-protected tables
```

Two separate apps in one repository:

| Directory | Description |
|-----------|-------------|
| `backend/` | Node.js/Express REST API + Socket.IO, port 3000 |
| `frontend/` | Flutter cross-platform app (Android, iOS, Web, Desktop) |

---

## Getting Started

### Backend
```bash
cd backend
npm install
npx prisma generate
npx prisma db push
node server.js
```

### Frontend
```bash
cd frontend
flutter pub get
flutter run -d chrome
```

### Environment Variables

**backend/.env**
```
SUPABASE_URL=
SUPABASE_KEY=
DATABASE_URL=
DIRECT_URL=
TU_API_KEY=
```

**frontend/.env**
```
SUPABASE_URL=
SUPABASE_ANON_KEY=
```

---

## Security

| Layer | Implementation |
|-------|---------------|
| Student verification | TU RESTful API — real TU accounts only |
| Authentication | JWT (30-day) + bcrypt password hashing |
| Database access | Supabase RLS — anon role restricted to public data only |
| Key management | Publishable key for frontend, secret key for backend only |
| Build-time secrets | `--dart-define` — keys injected at build time, not in source |
| Secret storage | `.env` gitignored, secrets stored in Railway and Firebase env vars |
| Transport | HTTPS enforced on both Firebase Hosting and Railway |

---

## Testing

```bash
cd backend
npm test
```

20 test files covering auth, chat, transactions, reviews, filters, and notifications — including property-based tests with fast-check and integration tests with supertest.

---

## Deployment

| Service | Platform |
|---------|----------|
| Backend API | Railway — auto-deploy on push |
| Frontend Web | Firebase Hosting — manual build and deploy |

**Frontend build command:**
```bash
flutter build web \
  --dart-define=SUPABASE_URL=your_url \
  --dart-define=SUPABASE_ANON_KEY=your_publishable_key
firebase deploy
```

---

<div align="center">
CN333 · Thammasat University · 2026
</div>
