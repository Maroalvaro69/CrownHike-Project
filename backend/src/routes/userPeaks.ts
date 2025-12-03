// backend/src/routes/userPeaks.ts
import express from 'express';
import { pool } from '../db/pool.js';
import { verifyToken } from '../middleware/authMiddleware.js';
import { awardBadgesForUser, awardBadgeByCode } from '../services/badges.js';

const router = express.Router();

/** POST /peaks/:id/mark — oznacz szczyt jako zdobyty */
router.post('/peaks/:id/mark', verifyToken, async (req, res) => {
  try {
    const peakId = Number(req.params.id);
    if (!Number.isInteger(peakId) || peakId <= 0) {
      return res.status(400).json({ ok: false, error: 'Invalid peak id' });
    }

    const userId = (req as any).user?.id;
    const { lat, lng, photo_url } = req.body;

    // sprawdź, czy szczyt istnieje
    const [[peak]]: any = await pool.query(
      'SELECT id, name FROM peaks WHERE id = ?',
      [peakId]
    );
    if (!peak) {
      return res.status(404).json({ ok: false, error: 'Peak not found' });
    }

    // próbujemy wstawić rekord zdobycia szczytu
    await pool.query(
      `INSERT INTO user_peaks (user_id, peak_id, lat, lng, photo_url)
       VALUES (?, ?, ?, ?, ?)`,
      [userId, peakId, lat ?? null, lng ?? null, photo_url ?? null]
    );

    // 1) odznaki progowe za liczbę różnych szczytów
    const newlyAwardedByCount = await awardBadgesForUser(userId);

    // 2) sprawdzenie 3 szczytów w jeden dzień
    const [[{ dayCount }]] = await pool.query(
      `SELECT COUNT(*) AS dayCount
         FROM user_peaks
        WHERE user_id = ?
          AND DATE(marked_at) = CURDATE()`,
      [userId]
    ) as any;

    const awardedSpecialBadges: string[] = [];

    if (dayCount >= 3) {
      if (await awardBadgeByCode(userId, 'THREE_PEAKS_ONE_DAY')) {
        awardedSpecialBadges.push('THREE_PEAKS_ONE_DAY');
      }
    }

    // 3) czasowe / sezonowe: poranny, zachód, nocny, zimowy
    const [[lastMark]] = await pool.query(
      `SELECT marked_at
         FROM user_peaks
        WHERE user_id = ? AND peak_id = ?
        ORDER BY marked_at DESC
        LIMIT 1`,
      [userId, peakId]
    ) as any;

    if (lastMark && lastMark.marked_at) {
      const markedAt = new Date(lastMark.marked_at);
      const hour = markedAt.getHours();       // 0–23
      const month = markedAt.getMonth() + 1;  // 1–12

      // Poranny Zdobywca – przed 8:00
      if (hour < 8) {
        if (await awardBadgeByCode(userId, 'MORNING_CLIMB')) {
          awardedSpecialBadges.push('MORNING_CLIMB');
        }
      }

      // Zachód – przykładowo 18–21
      if (hour >= 18 && hour <= 21) {
        if (await awardBadgeByCode(userId, 'SUNSET_CLIMB')) {
          awardedSpecialBadges.push('SUNSET_CLIMB');
        }
      }

      // Nocny – 22–4
      if (hour >= 22 || hour < 4) {
        if (await awardBadgeByCode(userId, 'NIGHT_CLIMB')) {
          awardedSpecialBadges.push('NIGHT_CLIMB');
        }
      }

      // Zimowy – grudzień, styczeń, luty
      if (month === 12 || month === 1 || month === 2) {
        if (await awardBadgeByCode(userId, 'WINTER_CLIMB')) {
          awardedSpecialBadges.push('WINTER_CLIMB');
        }
      }
    }

    res.status(201).json({
      ok: true,
      message: `Marked peak: ${peak.name}`,
      awardedBadges: newlyAwardedByCount,   // jak wcześniej (TATRA_1,3,...)
      awardedSpecialBadges,                 // nowe – kody specjalnych
    });
  } catch (e: any) {
    if (e.code === 'ER_DUP_ENTRY') {
      return res
        .status(400)
        .json({ ok: false, error: 'Peak already marked as completed' });
    }
    console.error(e);
    res.status(500).json({ ok: false, error: e.message });
  }
});

/** GET /me/peaks — lista zdobytych szczytów zalogowanego użytkownika */
router.get('/me/peaks', verifyToken, async (req, res) => {
  try {
    const userId = (req as any).user?.id;
    const [rows] = await pool.query(
      `SELECT up.id, up.marked_at, p.name, p.height_m, p.mountain_range,
              p.lat, p.lng, up.photo_url
         FROM user_peaks up
         JOIN peaks p ON p.id = up.peak_id
        WHERE up.user_id = ?
        ORDER BY up.marked_at DESC`,
      [userId]
    );
    res.json({ ok: true, count: (rows as any[]).length, data: rows });
  } catch (e: any) {
    console.error(e);
    res.status(500).json({ ok: false, error: e.message });
  }
});

export default router;
