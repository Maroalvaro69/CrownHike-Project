// src/routes/badges.ts
import express from 'express';
import { pool } from '../db/pool.js';
import { verifyToken, AuthRequest } from '../middleware/authMiddleware.js';

const router = express.Router();

/**
 * GET /api/badges
 * Lista wszystkich odznak (publiczna)
 */
router.get('/', async (_req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT
         id,
         code,
         name,
         description,
         required_peaks
       FROM badges
       ORDER BY id`
    );

    res.json({
      ok: true,
      data: rows,
    });
  } catch (err: any) {
    console.error(err);
    res
      .status(500)
      .json({ ok: false, error: err?.message ?? 'Internal server error' });
  }
});

/**
 * GET /api/badges/user
 * Odznaki zdobyte przez zalogowanego użytkownika
 */
router.get('/user', verifyToken, async (req, res) => {
  try {
    const authReq = req as AuthRequest;
    const userId = authReq.user?.id;

    if (!userId) {
      return res.status(401).json({ ok: false, error: 'Unauthorized' });
    }

    const [rows] = await pool.query(
      `SELECT
         b.id,
         b.code,
         b.name,
         b.description,
         b.required_peaks
       FROM user_badges ub
       JOIN badges b ON b.id = ub.badge_id
       WHERE ub.user_id = ?
       ORDER BY b.id`,
      [userId]
    );

    res.json({
      ok: true,
      data: rows,
    });
  } catch (err: any) {
    console.error(err);
    res
      .status(500)
      .json({ ok: false, error: err?.message ?? 'Internal server error' });
  }
});

/**
 * POST /api/badges/award-test
 * Prosty endpoint testowy: na podstawie liczby zdobytych szczytów
 * przyznaje odznaki, dla których required_peaks <= liczba szczytów.
 */
router.post('/award-test', verifyToken, async (req, res) => {
  try {
    const authReq = req as AuthRequest;
    const userId = authReq.user?.id;

    if (!userId) {
      return res.status(401).json({ ok: false, error: 'Unauthorized' });
    }

    // 1. Ile różnych szczytów ma użytkownik?
    const [countRows] = await pool.query(
      `SELECT COUNT(DISTINCT peak_id) AS cnt
       FROM user_peaks
       WHERE user_id = ?`,
      [userId]
    );
    const cnt = (countRows as any[])[0]?.cnt ?? 0;

    // 2. Jakie odznaki są "osiągalne" przy tej liczbie szczytów?
    const [eligibleRows] = await pool.query(
      `SELECT id, code, name, description, required_peaks
       FROM badges
       WHERE required_peaks IS NOT NULL
         AND required_peaks <= ?`,
      [cnt]
    );
    const eligible = eligibleRows as any[];

    const awarded: any[] = [];

    for (const badge of eligible) {
      const [existsRows] = await pool.query(
        `SELECT 1
         FROM user_badges
         WHERE user_id = ? AND badge_id = ?
         LIMIT 1`,
        [userId, badge.id]
      );

      const exists = (existsRows as any[]).length > 0;
      if (!exists) {
        await pool.query(
          `INSERT INTO user_badges (user_id, badge_id)
           VALUES (?, ?)`,
          [userId, badge.id]
        );
        awarded.push(badge);
      }
    }

    res.json({
      ok: true,
      awarded,
    });
  } catch (err: any) {
    console.error(err);
    res
      .status(500)
      .json({ ok: false, error: err?.message ?? 'Internal server error' });
  }
});

export default router;
