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
[![Live Demo](https://img.shields.io/badge/Live_Demo-54.254.88.0-FF9900?style=flat-square&logo=amazonaws)](http://54.254.88.0)

</div>

---

## Course & Institution

> **Course:** CN333 (Software Development Practice)  
> **Institution:** Thammasat University  

---

## Tech Stack & Ecosystem

<div align="center">

| Mobile App | Backend API | Database & Storage |
| :---: | :---: | :---: |
| ![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white) | ![NodeJS](https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=nodedotjs&logoColor=white) | ![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white) |
| ![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white) | ![Express](https://img.shields.io/badge/Express.js-000000?style=for-the-badge&logo=express&logoColor=white) | ![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white) |

| Real-time & Auth | Storage | Deployment |
| :---: | :---: | :---: |
| ![Socket.IO](https://img.shields.io/badge/Socket.IO-010101?style=for-the-badge&logo=socketdotio&logoColor=white) | ![Supabase Storage](https://img.shields.io/badge/Supabase_Storage-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white) | ![AWS](https://img.shields.io/badge/AWS-232F3E?style=for-the-badge&logo=amazonwebservices&logoColor=white) |
| ![JWT](https://img.shields.io/badge/JWT-000000?style=for-the-badge&logo=jsonwebtokens&logoColor=white) | ![Prisma](https://img.shields.io/badge/Prisma-2D3748?style=for-the-badge&logo=prisma&logoColor=white) | ![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white) |
| ![Nginx](https://img.shields.io/badge/Nginx-009639?style=for-the-badge&logo=nginx&logoColor=white) | ![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white) | ![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?style=for-the-badge&logo=github-actions&logoColor=white) |

</div>

---

## Key Features

### Verified Student Marketplace
* Access restricted via Thammasat University API integration.
* Registration and trading restricted to verified TU student credentials.

### Real-Time Communication
* Instant messaging infrastructure powered by Socket.IO.
* Push notifications for new messages, offers, and listing updates.

### Transaction Management
* Modular system for buying, selling, and renting campus items.
* Detailed listing management with multi-image support and categorized browsing.

### Data Persistence & Security
* Local data persistence using `shared_preferences` for improved UX.
* Secure media handling via Supabase Storage with Row-Level Security (RLS) policies.

---

## Architecture Overview

The platform utilizes a modern decoupled architecture to ensure scalability and security:

* **Data Flow:** `Flutter` → `REST API (Express)` → `Prisma ORM` → `PostgreSQL (Supabase)`
* **Real-Time Engine:** `Flutter` ↔ `Socket.IO (Express)` for low-latency chat services.
* **Asset Management:** `Flutter` → `Supabase Storage` for secure, authenticated media uploads.

---

## Deployment Configuration

| Service | Platform | Purpose |
| :--- | :--- | :--- |
| **Frontend & Backend** | AWS EC2 (Docker) | Containerized production environment |
| **Reverse Proxy** | Nginx | Routes traffic & handles rate-limiting |
| **Database** | Supabase | Managed PostgreSQL & Auth |
| **Storage** | Supabase | S3-Compatible Media Storage |
| **CI/CD** | GitHub Actions | Automated build, test, and deploy |
| **Infrastructure** | Terraform | Infrastructure-as-Code provisioning |

---

## Project Members

<table>
  <thead>
    <tr>
      <th align="center">Student ID</th>
      <th align="left">Name</th>
      <th align="left">Role & Responsibility</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td align="center"><b>6610685056</b></td>
      <td>Chonchanan Jitrawang</td>
      <td>Full-stack</td>
    </tr>
    <tr>
      <td align="center"><b>6610685098</b></td>
      <td>Kittidet Wichaidit</td>
      <td>Backend Developer</td>
    </tr>
    <tr>
      <td align="center"><b>6610685122</b></td>
      <td>Chayawat Kanjanakaew</td>
      <td>System Analyst & QA Tester</td>
    </tr>
    <tr>
      <td align="center"><b>6610685205</b></td>
      <td>Nonthapat Boonprasith</td>
      <td>DevOps & Frontend Developer</td>
    </tr>
    <tr>
      <td align="center"><b>6610685239</b></td>
      <td>Parunchai Timklip</td>
      <td>DevOps & Database</td>
    </tr>
  </tbody>
</table>

---
