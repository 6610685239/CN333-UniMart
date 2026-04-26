<div align="center">



<img src="https://readme-typing-svg.demolab.com?font=JetBrains+Mono&weight=700&size=32&pause=1000&color=7B1A1A&center=true&vCenter=true&width=800&lines=UniMart;Second-Hand+Marketplace+for+TU;Secure+Campus+Trading+Platform" alt="UniMart Typing" />



<br/>



A secure **Second-Hand Marketplace** exclusively for **Thammasat University students**.  

Buy, sell, and rent items within your campus — powered by **verified TU accounts only**.



---



![Platform](https://img.shields.io/badge/Platform-Mobile_%26_Web-7B1A1A?style=flat-square)

![Backend](https://img.shields.io/badge/Backend-Node.js_Express-black?style=flat-square)

![Frontend](https://img.shields.io/badge/Frontend-Flutter-blue?style=flat-square)

![Database](https://img.shields.io/badge/Database-PostgreSQL-336791?style=flat-square)

![Status](https://img.shields.io/badge/Status-Active_Development-8B0000?style=flat-square)



</div>



---



## Course & Institution



> **Course:** CN333  

> **Institution:** Thammasat University  



---



<div align="center">



## Tech Stack & Ecosystem



| Mobile App | Backend API | Database & Storage |

| :---: | :---: | :---: |

| ![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white) | ![NodeJS](https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=nodedotjs&logoColor=white) | ![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white) |

| ![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white) | ![Express](https://img.shields.io/badge/Express.js-000000?style=for-the-badge&logo=express&logoColor=white) | ![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white) |



| Realtime & Auth | Storage | Deployment |

| :---: | :---: | :---: |

| ![Socket.IO](https://img.shields.io/badge/Socket.IO-010101?style=for-the-badge&logo=socketdotio&logoColor=white)<br/>![JWT](https://img.shields.io/badge/JWT-000000?style=for-the-badge&logo=jsonwebtokens&logoColor=white) | ![Supabase Storage](https://img.shields.io/badge/Supabase_Storage-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white) | ![Railway](https://img.shields.io/badge/Railway-0B0D0E?style=for-the-badge&logo=railway&logoColor=white)<br/>![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black) |



</div>



---



## Key Features



### Verified Student Marketplace

- Access restricted via Thammasat University API  

- Only real TU students can register and trade  



### Real-Time Chat System

- Instant messaging powered by Socket.IO  

- Notifications for new messages and offers  



### Buy / Sell / Rent System

- List products with images and details  

- Browse campus-only listings safely  



### Favorites & Persistence

- Save items using shared_preferences  

- Personalized marketplace experience  



### Secure Media Storage

- Product images stored in Supabase Storage  

- Protected with Row-Level Security (RLS)  



---



## Architecture Overview


Flutter → REST API (Express) → Prisma → PostgreSQL (Supabase)

Flutter ↔ Socket.IO (Express) — real-time chat

Flutter → Supabase SDK — secure RLS data access





<div align="center">Deployment

ServicePlatformBackend APIRailwayFrontend WebFirebase Hosting



</div>

