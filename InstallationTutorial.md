# SmartAttend Installation Tutorial

This document provides step-by-step instructions to run the SmartAttend project for both the Frontend and Backend.

## 1. Prerequisites
Before starting, ensure you have the following installed:
* [Node.js](https://nodejs.org/) (v14 or later)
* [Flutter SDK](https://docs.flutter.dev/get-started/install)
* [NeonDB Account](https://neon.tech/)

---

## 2. Backend (Node.js & Express)

1.  **Navigate to the backend directory:**
    ```bash
    cd kompro-backend
    ```
2.  **Install dependencies:**
    ```bash
    npm install
    ```
3.  **Environment Variables Setup:**
    Create a `.env` file in the root of `kompro-backend` and add your NeonDB connection string:
    ```env
    PGUSER=your_username
    PGPASSWORD=your_password
    PGHOST=your_host_address
    PGDATABASE=neondb
    PGPORT=5432
    
    EMAIL_USER=your_email@gmail.com
    EMAIL_PASS=your_app_password
    ```
4.  **Run the server:**
    * Development mode:
        ```bash
        npm run dev
        ```
    * Normal mode:
        ```bash
        npm start
        ```
    > **Note:** Ensure your NeonDB "IP Allowlist" allows connections from your current IP address if the feature is enabled.

---

## 3. Frontend (Flutter)

1.  **Navigate to the frontend directory:**
    ```bash
    cd kompro_frontend
    ```
2.  **Install Flutter dependencies:**
    ```bash
    flutter pub get
    ```
3.  **IP Address Configuration:**
    The application automatically detects the platform in `auth_service.dart`:
    * **Android Emulator:** connects to `http://10.0.2.2:3000`
    * **Web/iOS/Desktop:** connects to `http://localhost:3000`

4.  **Run the application:**
    ```bash
    flutter run
    ```

---

## 4. Key Features
* **Cloud Database:** Powered by NeonDB (PostgreSQL) for scalable data storage.
* **Geofencing:** Radius-based attendance validation.
* **Two-Step Verification:** OTP security via email.
* **Admin Controls:** Dynamic office location settings and announcements.

---
Created for the SmartAttend Computing Project - 2026.
