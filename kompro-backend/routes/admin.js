/** @format */

import express from "express";
import nodemailer from "nodemailer";
import otpGenerator from "otp-generator";

// API LIST:
/* --- AUTH & 2FA --- */
// POST /admin/login
// POST /admin/forget-password
// POST /admin/verify-2fa
// POST /admin/resend-2fa

/* --- USER MANAGEMENT --- */
// GET    /admin/get-user-all
// POST   /admin/add-user
// PUT    /admin/edit-user
// DELETE /admin/delete-user

/* --- ATTENDANCE --- */
// GET  /admin/get-attendance
// POST /admin/get-attendance-user

/* --- NOTIFICATIONS --- */
// GET    /admin/get-notifications-all
// POST   /admin/add-notification
// DELETE /admin/delete-notification

/* --- OFFICE SETTINGS --- */
// GET  /admin/get-office-location
// POST /admin/set-office-location

export function createAdminRouter(pool) {
  const router = express.Router();

  /**
   * POST /admin/login
   * Authenticates admin/user and sends 2FA code via email.
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

      // Clear existing codes
      await pool.query("DELETE FROM user_2fa_codes WHERE user_id = $1", [
        user.user_id,
      ]);

      // Store new code (15 min expiry)
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
        from: '"MyApp Admin" <no-reply@myapp.com>',
        to: user.username_email,
        subject: "Your 2FA Verification Code",
        text: `Your verification code is: ${code}`,
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
   * POST /admin/forget-password
   */
  router.post("/forget-password", async (req, res) => {
    try {
      const { userId, email, newPassword } = req.body;

      if (!userId || !email || !newPassword) {
        return res
          .status(400)
          .send({ error: "userId, email, and newPassword are required" });
      }

      const userResult = await pool.query(
        'SELECT * FROM "User" WHERE user_id = $1 AND username_email = $2',
        [userId, email]
      );

      if (userResult.rows.length === 0) {
        return res.status(404).send({ error: "User not found" });
      }

      await pool.query(
        'UPDATE "User" SET password_hash = $1 WHERE user_id = $2',
        [newPassword, userId]
      );

      res
        .status(200)
        .send({ message: "Password updated successfully", userId, email });
    } catch (err) {
      console.error(err);
      res.status(500).send({ error: "Failed to reset password" });
    }
  });

  /**
   * POST /admin/verify-2fa
   */
  router.post("/verify-2fa", async (req, res) => {
    try {
      const { userId, code } = req.body;

      if (!userId || !code) {
        return res.status(400).send({ error: "userId and code are required" });
      }

      const codeResult = await pool.query(
        `SELECT * FROM user_2fa_codes 
         WHERE user_id = $1 AND LOWER(code) = LOWER($2) 
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
   * POST /admin/resend-2fa
   */
  router.post("/resend-2fa", async (req, res) => {
    try {
      const { userId } = req.body;
      if (!userId) return res.status(400).send({ error: "userId is required" });

      const userResult = await pool.query(
        'SELECT username_email FROM "User" WHERE user_id = $1',
        [userId]
      );
      if (userResult.rows.length === 0)
        return res.status(404).send({ error: "User not found" });

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
        auth: { user: process.env.EMAIL_USER, pass: process.env.EMAIL_PASS },
      });

      await transporter.sendMail({
        from: '"MyApp Admin" <no-reply@myapp.com>',
        to: email,
        subject: "Your New 2FA Code",
        text: `Your new verification code is: ${code}`,
      });

      res.status(200).send({ message: "2FA code resent", userId, email });
    } catch (err) {
      console.error(err);
      res.status(500).send({ error: "Failed to resend 2FA code" });
    }
  });

  /**
   * GET /admin/get-user-all
   */
  router.get("/get-user-all", async (req, res) => {
    try {
      const result = await pool.query(
        'SELECT user_id as "userId", name, username_email as "usernameEmail", role, nim_nip as "nimNip" FROM "User"'
      );
      res.status(200).send(result.rows);
    } catch (err) {
      console.error(err);
      res.status(500).send({ error: "Failed to fetch users" });
    }
  });

  /**
   * GET /admin/get-attendance
   */
  router.get("/get-attendance", async (req, res) => {
    try {
      const result = await pool.query(
        `SELECT attendance_id as "attendanceId", user_id as "userId", location_id as "locationId", 
         type, "timestamp", user_latitude as "userLatitude", user_longitude as "userLongitude", 
         status, notes FROM "Attendance" ORDER BY "timestamp" DESC`
      );
      res.status(200).send(result.rows);
    } catch (err) {
      console.error(err);
      res.status(500).send({ error: "Failed to fetch attendance" });
    }
  });

  /**
   * POST /admin/get-attendance-user
   */
  router.post("/get-attendance-user", async (req, res) => {
    try {
      const { userId } = req.body;
      if (!userId) return res.status(400).send({ error: "userId is required" });

      const result = await pool.query(
        `SELECT attendance_id as "attendanceId", user_id as "userId", location_id as "locationId", 
         type, "timestamp", user_latitude as "userLatitude", user_longitude as "userLongitude", 
         status, notes FROM "Attendance" WHERE user_id = $1 ORDER BY "timestamp" DESC`,
        [userId]
      );
      res.status(200).send(result.rows);
    } catch (err) {
      console.error(err);
      res.status(500).send({ error: "Failed to fetch user attendance" });
    }
  });

  /**
   * GET /admin/get-notifications-all
   */
  router.get("/get-notifications-all", async (req, res) => {
    try {
      const result = await pool.query(
        `SELECT notification_id as "notificationId", title, message, 
         to_char(created_at, 'YYYY-MM-DD HH24:MI:SS') as "createdAt"
         FROM notifications ORDER BY created_at DESC`
      );
      res.status(200).send(result.rows);
    } catch (err) {
      console.error(err);
      res.status(500).send({ error: "Failed to fetch notifications" });
    }
  });

  /**
   * POST /admin/add-notification
   */
  router.post("/add-notification", async (req, res) => {
    try {
      const { title, message } = req.body;
      if (!title || !message)
        return res
          .status(400)
          .send({ error: "Title and message are required" });

      const lastIdResult = await pool.query(
        "SELECT MAX(notification_id) FROM notifications"
      );
      const newId = (lastIdResult.rows[0].max || 0) + 1;

      await pool.query(
        "INSERT INTO notifications (notification_id, title, message, created_at) VALUES ($1, $2, $3, timezone('Asia/Jakarta', now()))",
        [newId, title, message]
      );

      res.status(201).send({
        success: true,
        message: "Notification sent successfully to all users",
      });
    } catch (err) {
      console.error(err);
      res.status(500).send({ error: "Failed to add notification" });
    }
  });

  /**
   * DELETE /admin/delete-notification
   */
  router.delete("/delete-notification", async (req, res) => {
    try {
      const { notificationId } = req.body;
      if (!notificationId)
        return res.status(400).send({ error: "notificationId is required" });

      const result = await pool.query(
        "DELETE FROM notifications WHERE notification_id = $1 RETURNING *",
        [notificationId]
      );
      if (result.rowCount === 0)
        return res.status(404).send({ error: "Notification not found" });

      res
        .status(200)
        .send({ success: true, deletedNotification: result.rows[0] });
    } catch (err) {
      console.error(err);
      res.status(500).send({ error: "Failed to delete notification" });
    }
  });

  /**
   * POST /admin/add-user
   */
  router.post("/add-user", async (req, res) => {
    try {
      const { name, usernameEmail, password, role, nimNip } = req.body;

      if (!name || !usernameEmail || !password) {
        return res
          .status(400)
          .send({ error: "Name, email, and password are required" });
      }

      const lastIdResult = await pool.query('SELECT MAX(user_id) FROM "User"');
      const newId = (lastIdResult.rows[0].max || 0) + 1;

      await pool.query(
        `INSERT INTO "User"(user_id, name, username_email, password_hash, role, nim_nip)
         VALUES($1, $2, $3, $4, $5, $6)`,
        [newId, name, usernameEmail, password, role || "user", nimNip || null]
      );

      res.status(201).send({
        success: true,
        message: "User created successfully",
        userId: newId,
      });
    } catch (err) {
      console.error(err);
      res.status(500).send({ error: "Failed to add user" });
    }
  });

  /**
   * PUT /admin/edit-user
   */
  router.put("/edit-user", async (req, res) => {
    try {
      const { userId, name, usernameEmail, password, role, nimNip } = req.body;
      if (!userId) return res.status(400).send({ error: "userId is required" });

      const checkUser = await pool.query(
        'SELECT * FROM "User" WHERE user_id = $1',
        [userId]
      );
      if (checkUser.rows.length === 0)
        return res.status(404).send({ error: "User not found" });

      const fields = [];
      const values = [];
      let idx = 1;

      if (name) {
        fields.push(`name = $${idx++}`);
        values.push(name);
      }
      if (usernameEmail) {
        fields.push(`username_email = $${idx++}`);
        values.push(usernameEmail);
      }
      if (password) {
        fields.push(`password_hash = $${idx++}`);
        values.push(password);
      }
      if (role) {
        fields.push(`role = $${idx++}`);
        values.push(role);
      }
      if (nimNip) {
        fields.push(`nim_nip = $${idx++}`);
        values.push(nimNip);
      }

      if (fields.length === 0)
        return res.status(400).send({ error: "No fields to update" });

      values.push(userId);
      const query = `UPDATE "User" SET ${fields.join(
        ", "
      )} WHERE user_id = $${idx}`;
      await pool.query(query, values);

      res.status(200).send({ success: true, userId });
    } catch (err) {
      console.error(err);
      res.status(500).send({ error: "Failed to update user" });
    }
  });

  /**
   * DELETE /admin/delete-user
   */
  router.delete("/delete-user", async (req, res) => {
    try {
      const { userId } = req.body;
      if (!userId) return res.status(400).send({ error: "userId is required" });

      const result = await pool.query(
        'DELETE FROM "User" WHERE user_id = $1 RETURNING *',
        [userId]
      );
      if (result.rowCount === 0)
        return res.status(404).send({ error: "User not found" });

      res.status(200).send({ success: true, deletedUserId: userId });
    } catch (err) {
      console.error(err);
      res.status(500).send({ error: "Failed to delete user" });
    }
  });

  /**
   * GET /admin/get-office-location
   */
  router.get("/get-office-location", async (req, res) => {
    try {
      const result = await pool.query(
        `SELECT location_id as "locationId", location_name as "locationName", latitude, longitude, radius, 
         created_at as "createdAt" FROM "Locations" WHERE location_id = 1`
      );
      res.status(200).send(result.rows);
    } catch (err) {
      console.error(err);
      res.status(500).send({ error: "Failed to fetch office location" });
    }
  });

  /**
   * POST /admin/set-office-location
   */
  router.post("/set-office-location", async (req, res) => {
    try {
      const { locationName, latitude, longitude, radius } = req.body;

      if (
        !locationName ||
        latitude === undefined ||
        longitude === undefined ||
        radius === undefined
      ) {
        return res.status(400).send({
          error: "locationName, latitude, longitude, and radius are required",
        });
      }

      const query = `
        INSERT INTO "Locations" (location_id, location_name, latitude, longitude, radius, created_at)
        VALUES (1, $1, $2, $3, $4, NOW())
        ON CONFLICT (location_id) 
        DO UPDATE SET 
          location_name = EXCLUDED.location_name,
          latitude = EXCLUDED.latitude,
          longitude = EXCLUDED.longitude,
          radius = EXCLUDED.radius;
      `;

      await pool.query(query, [locationName, latitude, longitude, radius]);

      res.status(200).send({
        success: true,
        message: "Office location updated successfully",
        locationId: 1,
      });
    } catch (err) {
      console.error(err);
      res.status(500).send({ error: "Failed to set office location" });
    }
  });

  return router;
}
