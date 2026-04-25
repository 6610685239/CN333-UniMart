# UniMart Frontend — File Map

Flutter app. All source files live under `lib/`.

---

## Entry Points

| File | Purpose |
|------|---------|
| `main.dart` | App entry point — initialises Supabase, dotenv, and launches `SplashScreen` |
| `config.dart` | Base URL selector (Web / Android emulator / iOS+Desktop) and uploads URL |

---

## Screens

### Auth & Onboarding

| File | Page |
|------|------|
| `features/onboarding/presentation/splash_screen.dart` | Splash — checks login state, routes to onboarding or home |
| `features/onboarding/presentation/onboarding_screen.dart` | 3-slide onboarding carousel (Browse · Safe · Chat) |
| `screens/login_screen.dart` | Login — TU credential + UniMart password |
| `screens/register_screen.dart` | Registration — TU verification then set password |
| `screens/change_password_screen.dart` | Change password (authenticated) |

### Shell & Navigation

| File | Page |
|------|------|
| `screens/main_screen.dart` | Root scaffold — holds bottom nav, switches between tab pages, polls unread notification count |
| `shared/widgets/bottom_nav.dart` | Custom 5-tab bottom nav bar (Home · Chat · Sell FAB · Saved · Me) |

### Home

| File | Page |
|------|------|
| `screens/home_screen.dart` | Thin stateful wrapper — fetches products, passes data down to `HomePage` |
| `pages/home_page.dart` | Full home UI — banner carousel, search bar, type filter pills, category chips, Trending row, Recently Added grid |

### Products

| File | Page |
|------|------|
| `screens/product_detail_screen.dart` | Product detail — image hero, title/price, seller card (star + deals), info rows (status/condition/category/stock), description, meeting point, buy/rent/chat bottom bar |
| `screens/all_products_screen.dart` | "See all" grid — shown when tapping a section header on home |
| `screens/add_product_screen.dart` | Create new listing — images, title, price, category, condition, location |
| `screens/edit_product_screen.dart` | Edit existing listing — same form as add, pre-filled |
| `screens/filter_sheet.dart` | Filter bottom sheet — price range, category, type, condition |
| `screens/my_shop_screen.dart` | Owner's own listings — manage active/sold items |

### Chat

| File | Page |
|------|------|
| `screens/chat_list_screen.dart` | Chat list — all rooms for the current user |
| `screens/chat_room_screen.dart` | Chat room — real-time messages via Socket.IO |

### Transactions

| File | Page |
|------|------|
| `screens/transaction_list_screen.dart` | Transaction list — buy/rent history |
| `screens/transaction_detail_screen.dart` | Transaction detail — status tracker, confirm/cancel actions |

### Reviews

| File | Page |
|------|------|
| `screens/review_screen.dart` | Leave a review after a completed transaction |

### Notifications

| File | Page |
|------|------|
| `screens/notification_screen.dart` | Notification inbox — system and transaction alerts |

### Profile & Seller

| File | Page |
|------|------|
| `screens/user_profile_screen.dart` | Own profile — avatar, name, faculty, TU status, logout |
| `screens/seller_profile_screen.dart` | Seller profile (read-only) — avatar, stats, listings grid |

### Saved / Favourites

| File | Page |
|------|------|
| `pages/favourited_page.dart` | Saved items grid — products the user has hearted |
| `pages/favourite_manager.dart` | Singleton state manager for favourite toggle + count (not a page) |

---

## Models

| File | Represents |
|------|-----------|
| `models/product.dart` | Product (id, title, price, condition, type, images, quantity, …) |
| `models/category.dart` | Category (id, name) |
| `models/chat_message.dart` | Chat message (id, roomId, senderId, body, createdAt) |
| `models/chat_room.dart` | Chat room (id, participants, last message preview) |
| `models/transaction.dart` | Transaction (id, type SALE/RENT, status, buyer, product) |
| `models/review.dart` | Review (id, rating 1–5, comment, reviewerId, revieweeId) |
| `models/app_notification.dart` | In-app notification (id, userId, message, read flag) |

---

## Services

| File | Calls |
|------|-------|
| `services/api_service.dart` | General REST — products, categories, status updates, delete |
| `services/auth_service.dart` | Auth — login, register, TU verification, profile |
| `services/chat_service.dart` | Chat rooms — create/open room |
| `services/filter_service.dart` | Product filter endpoint |
| `services/notification_service.dart` | Notifications — fetch, mark read, unread count |
| `services/review_service.dart` | Reviews — create review, get user reviews, credit score |
| `services/transaction_service.dart` | Transactions — create, list, update status |

---

## Shared / Theme

| File | Purpose |
|------|---------|
| `shared/theme/app_colors.dart` | Design tokens — ink, bg, surface, border, accent (#F5C518), success, … |
| `shared/theme/app_text_styles.dart` | Base text styles (caption, body, etc.) |
| `shared/theme/app_theme.dart` | `ThemeData` applied at the root |

---

## Onboarding Widgets

| File | Widget |
|------|--------|
| `features/onboarding/widgets/page_dots.dart` | Animated page indicator dots |
| `features/onboarding/widgets/illustration_card.dart` | Slide 1 illustration |
| `features/onboarding/widgets/illustration_shield.dart` | Slide 2 illustration |
| `features/onboarding/widgets/illustration_chat.dart` | Slide 3 illustration |

---

## Key Relationships

```
main.dart
└── SplashScreen
    ├── OnboardingScreen → LoginScreen
    └── MainScreen  (authenticated)
        ├── [0] HomeScreen → HomePage
        │         ├── ProductDetailScreen
        │         ├── AllProductsScreen → ProductDetailScreen
        │         └── FilterSheet
        ├── [1] ChatListScreen → ChatRoomScreen
        ├── [2] AddProductScreen          (FAB, not a tab)
        ├── [3] FavouritedPage → ProductDetailScreen
        └── [4] UserProfileScreen
                  └── MyShopScreen → EditProductScreen
```

> **Socket.IO** is used in `ChatRoomScreen` for real-time messages and in `MainScreen` for live notification polling.
> **Supabase SDK** is used directly for RLS-protected tables (favourites) and Storage (product images).
