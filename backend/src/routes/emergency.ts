// backend/src/routes/emergency.ts
import express from 'express';
import { pool } from '../db/pool.js';
import { verifyToken } from '../middleware/authMiddleware.js';
import { awardBadgeByCode } from '../services/badges.js';

const router = express.Router();

type EmergencyCard = {
  phone?: string | null;
  emergency_contact_name?: string | null;
  emergency_contact_phone?: string | null;
  blood_type?: string | null;
  address_street?: string | null;
  address_house_number?: string | null;
  address_postal_code?: string | null;
  address_city?: string | null;
  allergies?: string | null;
  medications?: string | null;
  todays_plan?: string | null;
};

// GET /api/emergency/me
router.get('/me', verifyToken, async (req, res) => {
  try {
    const userId = (req as any).user.id as number;

    const [rows] = await pool.query(
      `SELECT phone, emergency_contact_name, emergency_contact_phone,
              blood_type, address_street, address_house_number,
              address_postal_code, address_city,
              allergies, medications, todays_plan
         FROM user_emergency
        WHERE user_id = ?`,
      [userId]
    );

    const card = (rows as any[])[0] ?? {};
    res.json({ ok: true, data: card });
  } catch (err: any) {
    console.error(err);
    res.status(500).json({ ok: false, error: err.message });
  }
});

// PUT /api/emergency/me
router.put('/me', verifyToken, async (req, res) => {
  try {
    const userId = (req as any).user.id as number;
    const {
      phone,
      emergency_contact_name,
      emergency_contact_phone,
      blood_type,
      address_street,
      address_house_number,
      address_postal_code,
      address_city,
      allergies,
      medications,
      todays_plan,
    } = req.body as EmergencyCard;

    // POPRAWIONE ZAPYTANIE (12 kolumn, 12 placeholderów)
    await pool.query(
      `INSERT INTO user_emergency
         (user_id, phone, emergency_contact_name, emergency_contact_phone,
          blood_type, address_street, address_house_number,
          address_postal_code, address_city,
          allergies, medications, todays_plan)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE
          phone = VALUES(phone),
          emergency_contact_name = VALUES(emergency_contact_name),
          emergency_contact_phone = VALUES(emergency_contact_phone),
          blood_type = VALUES(blood_type),
          address_street = VALUES(address_street),
          address_house_number = VALUES(address_house_number),
          address_postal_code = VALUES(address_postal_code),
          address_city = VALUES(address_city),
          allergies = VALUES(allergies),
          medications = VALUES(medications),
          todays_plan = VALUES(todays_plan)`,
      [
        userId,
        phone ?? null,
        emergency_contact_name ?? null,
        emergency_contact_phone ?? null,
        blood_type ?? null,
        address_street ?? null,
        address_house_number ?? null,
        address_postal_code ?? null,
        address_city ?? null,
        allergies ?? null,
        medications ?? null,
        todays_plan ?? null,
      ]
    );

    // odznaki za wypełnienie danych
    const hasBasicSafetyData =
      !!emergency_contact_phone ||
      !!emergency_contact_name ||
      !!phone ||
      !!blood_type;

    if (hasBasicSafetyData) {
      await awardBadgeByCode(userId, 'SAFETY_CARD_FILLED');
    }

    if (todays_plan && todays_plan.trim().length > 0) {
      await awardBadgeByCode(userId, 'TODAYS_PLAN_SET');
    }

    res.json({ ok: true });
  } catch (err: any) {
    console.error(err);
    res.status(500).json({ ok: false, error: err.message });
  }
});

export default router;