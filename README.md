# 📍 LocalDrop

> **"From Creator Reach to Store Visits"** — A Performance-Based Influencer Matchmaking and Footfall Attribution Platform for Neighborhood Businesses.

LocalDrop is a hyper-local, performance-based influencer marketing platform connecting neighborhood businesses (cafes, boutiques, salons) with local creators. It translates vanity metrics ("likes" and "views") into **real physical store walk-ins** and revenue using **audience location matching**, **predictive footfall AI**, and **geofenced QR codes**.

---

## 🚀 Key Features

*   **Audience Cluster Matching:** Compares creator follower hotspots with business coordinates using Leaflet map visualization and spatial queries.
*   **Predictive Footfall AI:** Computes a composite match score (Geo Overlap + Niche Alignment + Conversions + Affinity) to estimate customer walk-ins and expected store ROI.
*   **Double-Geo Guard (Anti-Fraud):** Validates locations at both offer claim (customer) and coupon checkout (merchant) using the Haversine distance formula to prevent off-site redemption spoofing.
*   **48-Hour Escrow Hold:** Holds creator earnings for 48 hours to allow merchants to audit transactions and raise disputes, securing trust.
*   **Multi-Lingual Support:** Fully localized in English and Hindi for tier-2/tier-3 city adoption.

---

## 🛠️ Tech Stack

### Frontend
*   **Framework:** Next.js 15 (App Router, TypeScript)
*   **Styling:** Tailwind CSS (Modern Neobrutalism UI style with high contrast, offset borders, and bright accents)
*   **Mapping:** Leaflet.js & React-Leaflet (For geofence zones, outlets, and audience heatmaps)
*   **State & Cache:** React Query (TanStack Query) & Zustand (Auth Store)
*   **Icons:** Lucide React

### Backend
*   **Runtime:** Node.js (Express, JavaScript)
*   **Database Client:** `pg` (PostgreSQL Client with Connection Pool)
*   **Authentication:** JSON Web Tokens (JWT) with Access/Refresh cycle
*   **Security:** HMAC signatures for secure public voucher verification

### Database
*   **Engine:** PostgreSQL 15+
*   **Extensions:** `pgcrypto` for UUID generation
*   **Key Schemas:** `users`, `creator_profiles`, `business_profiles`, `campaigns`, `qr_codes`, `redemptions`, `earnings`, `disputes`, `payouts`, and `audience_clusters` (with automated indices and trigger functions for timestamp tracking).

---

## ⚙️ Architecture & How It Works

```
                        ┌────────────────────────┐
                        │    Next.js Frontend    │
                        │      (Port 3001)       │
                        └───────────┬────────────┘
                                    │
                       HTTP API     │ (JWT Authenticated)
                       Requests     ▼
                        ┌────────────────────────┐
                        │   Express JS Backend   │
                        │      (Port 3000)       │
                        └───────────┬────────────┘
                                    │
                         Queries    │
                         & Joins    ▼
                        ┌────────────────────────┐
                        │  PostgreSQL Database   │
                        │      (Port 5432)       │
                        └────────────────────────┘
```

1.  **Campaign Setup:** A **Business** creates a geofenced campaign (e.g., flat 20% off) centered at their store outlet with a target budget.
2.  **Matchmaking Map:** The **Creator** views potential matches on a map. Our spatial matching algorithm compares the creator's audience hotspots (`audience_clusters`) against the store's branch coordinates (`store_locations`).
3.  **Voucher Claiming:** When a customer scans a creator's unique QR code, they are redirected to a public landing page (`/c/[token]`). They claim the offer by sharing their GPS location. A signed redemption code is generated.
4.  **Counter Verification:** At store checkout, the customer displays their redemption QR. The cashier scans it (or enters it manually) on `/business/redeem`. The platform compares the customer's coordinate log with the cashier's GPS location. 
5.  **Hold & Dispute:** If the transaction is geofenced successfully, the creator earns their commission. The earnings enter a 48-hour pending escrow. If a dispute is raised, it is reviewed by the platform **Admin**; otherwise, the balance becomes available for UPI/Bank payout.

---

## 🛠️ Setup & Operation Guide

### Option A: Run via Docker Compose (Recommended)
This runs the entire stack—Database, Backend, and Frontend—with database migrations and seeds pre-loaded.

1.  Clone this repository and navigate to the project root.
2.  Run the following command:
    ```bash
    docker-compose up --build
    ```
3.  **Port Mapping:**
    *   **Frontend:** `http://localhost:3001`
    *   **Backend:** `http://localhost:3000`
    *   **Database:** `localhost:5432`

---

### Option B: Run Manually (Local Development)

#### 1. Database Setup (PostgreSQL)
1.  Create a database named `localdrop` in your PostgreSQL instance.
2.  Create a `.env` file in the `localdrop-backend` folder matching the variables in `.env.example`:
    ```env
    PORT=3000
    NODE_ENV=development
    DB_HOST=localhost
    DB_PORT=5432
    DB_NAME=localdrop
    DB_USER=postgres
    DB_PASSWORD=yourpostgrespassword
    JWT_ACCESS_SECRET=your_jwt_access_secret
    JWT_REFRESH_SECRET=your_jwt_refresh_secret
    QR_HMAC_SECRET=your_qr_hmac_secret
    FRONTEND_URL=http://localhost:3001
    ```

#### 2. Backend Installation & Migrations
1.  Navigate to the backend folder:
    ```bash
    cd hack\ \(2\)\hack\ \(2\)\hack\hack\localdrop-backend
    ```
2.  Install dependencies:
    ```bash
    npm install
    ```
3.  Run migrations (creates tables) and seed script (populates mock creators, businesses, and Indore campaigns/outlets):
    ```bash
    node src/db/migrate.js
    node src/db/seed.js
    ```
4.  Start the Express server:
    ```bash
    npm start
    ```
    *The API will run at `http://localhost:3000`.*

#### 3. Frontend Installation & Operation
1.  Navigate to the frontend folder:
    ```bash
    cd ..\localdrop-frontend
    ```
2.  Create a `.env` file containing the backend URL:
    ```env
    NEXT_PUBLIC_API_URL=http://localhost:3000/api
    ```
3.  Install dependencies:
    ```bash
    npm install
    ```
4.  Start the Next.js development server:
    ```bash
    npm run dev
    ```
    *The web interface will run at `http://localhost:3001`.*

---

## 📂 Project Structure

```
localdrop/
├── docker-compose.yml          # Global Docker multi-container run script
├── localdrop-backend/
│   ├── src/
│   │   ├── controllers/        # Express request routing controllers (Auth, Campaign, QR, Payouts)
│   │   ├── db/                 # Migrations, seed scripts, schema definitions, and db pool
│   │   ├── middleware/         # Auth checkers, route error handling
│   │   ├── routes/             # REST API endpoint definitions (including Gemini AI Droppy assistant)
│   │   ├── services/           # DB transactional logic helpers (QR creation, earnings holds)
│   │   └── utils/              # Crypto and Geo-Haversine calculation modules
│   └── server.js               # Backend entrypoint
│
└── localdrop-frontend/
    ├── src/
    │   ├── app/                # Next.js Pages (Auth layouts, dashboards for Business/Creator/Admin)
    │   ├── components/         # Leaflet Maps, AI Assistant Drawer, Charts, UI layout primitives
    │   ├── hooks/              # API hooks bound to React Query mutations
    │   ├── i18n/               # Hindi/English localization translations
    │   ├── lib/                # API fetch classes, services wrappers, and utils
    │   └── store/              # Zustand Auth session stores
    └── tailwind.config.ts      # Neobrutalist design layout parameters
```

---

## 🔑 Demo Access Credentials (Loaded via Seeds)

Use these credentials to test dashboard components:

*   **Creator Account:**
    *   *Email:* `creator@localdrop.com`
    *   *Password:* `creator123`
*   **Business Account:**
    *   *Email:* `business@localdrop.com`
    *   *Password:* `business123`
*   **Admin Account:**
    *   *Email:* `admin@localdrop.com`
    *   *Password:* `admin123`
