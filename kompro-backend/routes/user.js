/** @format */

import express from "express";
import nodemailer from "nodemailer";
import otpGenerator from "otp-generator";
import { getDistanceInMeters } from "../lib.js";

// API LIST:

/* --- AUTHENTICATION & 2FA --- */
// POST /user/login
// POST /user/update-password
// POST /user/verify-2fa
// POST /user/resend-2fa

/* --- NOTIFICATION --- */
// GET /user/get-notification-latest
// GET /user/get-notifications-all

/* --- PROFILE --- */
// POST /user/get-user

/* --- ATTENDANCE --- */
// POST /user/get-attendance-user
// POST /user/checkin
// POST /user/checkout

/* --- OFFICE --- */
// GET /user/get-office-location

export function createUserRouter(pool) {
  const router = express.Router();

  /**
   * POST /user/login
   * Authenticates user and sends a 2FA code via email.
   */
  router.post("/login", async (req, res) => {
    try {
      const { email, password } = req.body;
      if (!email || !password) {
        return res
          .status(400)
          .send({ error: "Email and password are required" });
      }

      const result = await pool.query(
        'SELECT user_id, username_email, password_hash FROM "User" WHERE username_email = $1',
        [email]
      );

      if (result.rows.length === 0) {
        return res.status(401).send({ error: "User not found" });
      }

      const user = result.rows[0];

      if (user.password_hash !== password) {
        return res.status(401).send({ error: "Invalid password" });
      }

      const code = otpGenerator.generate(6, {
        upperCaseAlphabets: false,
        specialChars: false,
      });

      await pool.query("DELETE FROM user_2fa_codes WHERE user_id = $1", [
        user.user_id,
      ]);

      await pool.query(
        "INSERT INTO user_2fa_codes(user_id, code, expires_at) VALUES($1, $2, timezone('Asia/Jakarta', now()) + INTERVAL '15 minutes')",
        [user.user_id, code]
      );

      const transporter = nodemailer.createTransport({
        service: "gmail",
        auth: {
          user: process.env.EMAIL_USER,
          pass: process.env.EMAIL_PASS,
        },
      });

      await transporter.sendMail({
        from: '"SmartAttend" <no-reply@myapp.com>',
        to: user.username_email,
        subject: "Your 2FA code",
        text: `Your 2FA code is: ${code}`,
      });

      res.status(200).send({
        message: "Login successful, 2FA code sent",
        userId: user.user_id,
        email: user.username_email,
      });
    } catch (err) {
      console.error(err);
      res.status(500).send({ error: "Login failed" });
    }
  });

  /**
   * POST /user/update-password
   * Updates the user's password after verifying the current one.
   */
  router.post("/update-password", async (req, res) => {
    try {
      const userId = parseInt(req.body.userId);
      const { currentPassword, newPassword } = req.body;

      if (!userId || !currentPassword || !newPassword) {
        return res.status(400).send({
          error: "userId, currentPassword, and newPassword are required",
        });
      }

      const userResult = await pool.query(
        'SELECT password_hash FROM "User" WHERE user_id = $1',
        [userId]
      );

      if (userResult.rows.length === 0) {
        return res.status(404).send({ error: "User not found" });
      }

      const user = userResult.rows[0];

      if (user.password_hash !== currentPassword) {
        return res.status(401).send({ error: "Current password is incorrect" });
      }

      await pool.query(
        'UPDATE "User" SET password_hash = $1 WHERE user_id = $2',
        [newPassword, userId]
      );

      res.status(200).send({ message: "Password updated successfully" });
    } catch (err) {
      console.error(err);
      res.status(500).send({ error: "Failed to update password" });
    }
  });

  /**
   * POST /user/verify-2fa
   * Verifies the 2FA code and completes authentication.
   */
  router.post("/verify-2fa", async (req, res) => {
    try {
      const { userId, code } = req.body;
      if (!userId || !code) {
        return res.status(400).send({ error: "userId and code are required" });
      }

      const codeResult = await pool.query(
        `SELECT * FROM user_2fa_codes 
          WHERE user_id = $1 
          AND LOWER(code) = LOWER($2) 
          AND expires_at > timezone('Asia/Jakarta', now())`,
        [userId, code]
      );

      if (codeResult.rows.length === 0) {
        return res.status(401).send({ error: "Invalid or expired code" });
      }

      await pool.query(
        "DELETE FROM user_2fa_codes WHERE user_id = $1 AND code = $2",
        [userId, code]
      );

      const userResult = await pool.query(
        'SELECT username_email FROM "User" WHERE user_id = $1',
        [userId]
      );

      res.status(200).send({
        message: "2FA verified",
        userId,
        email: userResult.rows[0].username_email,
      });
    } catch (err) {
      console.error(err);
      res.status(500).send({ error: "2FA verification failed" });
    }
  });

  /**
   * POST /user/resend-2fa
   * Generates and sends a new 2FA code.
   */
  router.post("/resend-2fa", async (req, res) => {
    try {
      const { userId } = req.body;
      if (!userId) {
        return res.status(400).send({ error: "userId is required" });
      }

      const userResult = await pool.query(
        'SELECT username_email FROM "User" WHERE user_id = $1',
        [userId]
      );
      if (userResult.rows.length === 0) {
        return res.status(404).send({ error: "User not found" });
      }

      const email = userResult.rows[0].username_email;
      const code = otpGenerator.generate(6, {
        upperCaseAlphabets: false,
        specialChars: false,
      });

      await pool.query("DELETE FROM user_2fa_codes WHERE user_id = $1", [
        userId,
      ]);

      await pool.query(
        "INSERT INTO user_2fa_codes(user_id, code, expires_at) VALUES($1, $2, timezone('Asia/Jakarta', now()) + INTERVAL '15 minutes')",
        [userId, code]
      );

      const transporter = nodemailer.createTransport({
        service: "gmail",
        auth: {
          user: process.env.EMAIL_USER,
          pass: process.env.EMAIL_PASS,
        },
      });

      await transporter.sendMail({
        from: `"SmartAttend" <no-reply@myapp.com>`,
        to: email,
        subject: "Your new 2FA code",
        text: `Your new 2FA code is: ${code}`,
      });

      res.status(200).send({ message: "2FA code resent", userId, email });
    } catch (err) {
      console.error(err);
      res.status(500).send({ error: "Failed to resend 2FA code" });
    }
  });

  /**
   * GET /user/get-notification-latest
   * Fetches the single most recent notification.
   */
  router.get("/get-notification-latest", async (req, res) => {
    try {
      const result = await pool.query(
        `SELECT 
        notification_id, 
        title, 
        message, 
        to_char(created_at, 'YYYY-MM-DD HH24:MI:SS') as created_at 
      FROM notifications 
      ORDER BY created_at DESC 
      LIMIT 1`
      );

      if (result.rows.length === 0) {
        return res.status(404).send({ error: "No notifications found" });
      }

      const row = result.rows[0];
      res.status(200).send({
        notificationId: row.notification_id,
        title: row.title,
        message: row.message,
        createdAt: row.created_at,
      });
    } catch (err) {
      console.error(err);
      res.status(500).send({ error: "Failed to fetch latest notification" });
    }
  });

  /**
   * GET /user/get-notifications-all
   * Fetches all notifications for a specific user.
   */
  router.get("/get-notifications-all", async (req, res) => {
    try {
      const userId = req.query.userId;
      if (!userId) {
        return res.status(400).send({ error: "userId is required" });
      }

      const result = await pool.query(
        "SELECT notification_id, title, message, created_at FROM notifications ORDER BY created_at DESC"
      );

      res.status(200).send(
        result.rows.map((row) => ({
          notificationId: row.notification_id,
          title: row.title,
          message: row.message,
          createdAt: row.created_at,
        }))
      );
    } catch (err) {
      console.error(err);
      res.status(500).send({ error: "Failed to fetch notifications" });
    }
  });

  /**
   * POST /user/get-user
   * Retrieves user profile information.
   */
  router.post("/get-user", async (req, res) => {
    try {
      const { userId } = req.body;
      if (!userId) {
        return res.status(400).send({ error: "userId is required" });
      }

      const result = await pool.query(
        'SELECT user_id, name, username_email, role, nim_nip FROM "User" WHERE user_id = $1',
        [userId]
      );

      if (result.rows.length === 0) {
        return res.status(404).send({ error: "User not found" });
      }

      const user = result.rows[0];
      res.status(200).send({
        userId: user.user_id,
        name: user.name,
        email: user.username_email,
        role: user.role,
        nim_nip: user.nim_nip,
      });
    } catch (err) {
      console.error(err);
      res.status(500).send({ error: "Failed to fetch user" });
    }
  });

  /**
   * POST /user/get-attendance-user
   * Retrieves attendance history for a specific user.
   */
  router.post("/get-attendance-user", async (req, res) => {
    try {
      const { userId } = req.body;
      if (!userId) {
        return res.status(400).send({ error: "userId is required" });
      }

      const result = await pool.query(
        `SELECT attendance_id, user_id, location_id, type, "timestamp", user_latitude, user_longitude, status, notes
       FROM "Attendance"
       WHERE user_id = $1
       ORDER BY "timestamp" DESC`,
        [userId]
      );

      res.status(200).send(
        result.rows.map((row) => ({
          attendanceId: row.attendance_id,
          userId: row.user_id,
          locationId: row.location_id,
          type: row.type,
          timestamp: row.timestamp,
          userLatitude: row.user_latitude,
          userLongitude: row.user_longitude,
          status: row.status,
          notes: row.notes,
        }))
      );
    } catch (err) {
      console.error(err);
      res.status(500).send({ error: "Failed to fetch attendance" });
    }
  });

  /**
   * Internal Attendance Helper
   * Handles the logic for both check-in and check-out.
   */
  const processAttendance = async (req, res, type) => {
    try {
      const { userId, userLatitude, userLongitude, notes } = req.body;
      if (!userId || userLatitude == null || userLongitude == null) {
        return res.status(400).send({
          error: "userId, userLatitude, and userLongitude are required",
        });
      }

      const locationResult = await pool.query(
        'SELECT latitude, longitude, radius FROM "Locations" WHERE location_id = 1'
      );
      if (locationResult.rows.length === 0) {
        return res
          .status(500)
          .send({ error: "Office location configuration not found" });
      }

      const office = locationResult.rows[0];
      const distance = getDistanceInMeters(
        userLatitude,
        userLongitude,
        office.latitude,
        office.longitude
      );

      if (distance > office.radius) {
        return res
          .status(403)
          .send({ error: `You are outside the allowed ${type} area` });
      }

      const result = await pool.query(
        `INSERT INTO "Attendance" (user_id, location_id, type, user_latitude, user_longitude, notes)
         VALUES ($1, 1, $2, $3, $4, $5) RETURNING attendance_id, "timestamp"`,
        [userId, type, userLatitude, userLongitude, notes || null]
      );

      res.status(200).send({
        message: `${
          type.charAt(0).toUpperCase() + type.slice(1)
        } recorded successfully`,
        attendanceId: result.rows[0].attendance_id,
        timestamp: result.rows[0].timestamp,
      });
    } catch (err) {
      console.error(err);
      res.status(500).send({ error: `Failed to record ${type}` });
    }
  };

  router.post("/checkin", (req, res) =>
    processAttendance(req, res, "check-in")
  );
  router.post("/checkout", (req, res) =>
    processAttendance(req, res, "checkout")
  );

  /**
   * GET /user/get-office-location
   * Retrieves the designated office coordinates and allowed radius.
   */
  router.get("/get-office-location", async (req, res) => {
    try {
      const result = await pool.query(
        'SELECT location_id, location_name, latitude, longitude, radius, created_at FROM "Locations" WHERE location_id = 1'
      );

      if (result.rows.length === 0) {
        return res.status(404).send({ error: "Office location not found" });
      }

      const row = result.rows[0];
      res.status(200).send({
        locationId: row.location_id,
        locationName: row.location_name,
        latitude: row.latitude,
        longitude: row.longitude,
        radius: row.radius,
        createdAt: row.created_at,
      });
    } catch (err) {
      console.error(err);
      res.status(500).send({ error: "Failed to fetch office location" });
    }
  });

  return router;
}
