import express from 'express';
import type { ResultSetHeader } from 'mysql2';
import { pool } from '../db/pool.js';
import { verifyToken, AuthRequest } from '../middleware/authMiddleware.js';

const router = express.Router();

/**
 * GET /hikes
 * Lista wędrówek zalogowanego użytkownika
 */
router.get('/', verifyToken, async (req: AuthRequest, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({ ok: false, error: 'Unauthorized' });
    }

    const [rows] = await pool.query(
      `SELECT
         h.id,
         h.peak_id,
         p.name            AS peak_name,
         p.height_m        AS peak_height_m,
         p.mountain_range  AS peak_range,
         h.started_at,
         h.duration_sec,
         h.track_distance_km,
         h.straight_distance_km,
         h.created_at
       FROM hikes h
       JOIN peaks p ON p.id = h.peak_id
      WHERE h.user_id = ?
      ORDER BY h.started_at DESC, h.id DESC`,
      [userId],
    );

    return res.json({
      ok: true,
      count: (rows as any[]).length,
      data: rows,
    });
  } catch (e: any) {
    console.error(e);
    return res.status(500).json({ ok: false, error: e.message });
  }
});

/**
 * GET /hikes/:id
 * Szczegóły pojedynczej wędrówki + ślad (na przyszłość pod mapę)
 */
router.get('/:id', verifyToken, async (req: AuthRequest, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({ ok: false, error: 'Unauthorized' });
    }

    const hikeId = Number(req.params.id);
    if (!Number.isInteger(hikeId) || hikeId <= 0) {
      return res.status(400).json({ ok: false, error: 'Invalid hike id' });
    }

    const [rows] = await pool.query(
      `SELECT
         h.id,
         h.user_id,
         h.peak_id,
         p.name            AS peak_name,
         p.height_m        AS peak_height_m,
         p.mountain_range  AS peak_range,
         h.started_at,
         h.duration_sec,
         h.track_distance_km,
         h.straight_distance_km,
         h.created_at
       FROM hikes h
       JOIN peaks p ON p.id = h.peak_id
      WHERE h.id = ? AND h.user_id = ?
      LIMIT 1`,
      [hikeId, userId],
    );

    const list = rows as any[];

if (list.length === 0) {
  return res.status(404).json({ ok: false, error: 'Hike not found' });
}

const header = list[0];


    const [pointsRows] = await pool.query(
      `SELECT seq, lat, lng
         FROM hike_points
        WHERE hike_id = ?
        ORDER BY seq ASC`,
      [hikeId],
    );

    return res.json({
      ok: true,
      data: {
        ...header,
        track: pointsRows,
      },
    });
  } catch (e: any) {
    console.error(e);
    return res.status(500).json({ ok: false, error: e.message });
  }
});

/**
 * POST /hikes
 * Zapis nowej wędrówki (to już masz, tylko zostawiamy jako część pliku)
 *
 * Body:
 *  - peakId: number
 *  - startedAt: string (ISO)
 *  - durationSec: number
 *  - trackDistanceKm: number
 *  - straightDistanceKm?: number
 *  - track: { lat: number, lng: number }[]
 */
router.post('/', verifyToken, async (req: AuthRequest, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({ ok: false, error: 'Unauthorized' });
    }

    const {
      peakId,
      startedAt,
      durationSec,
      trackDistanceKm,
      straightDistanceKm,
      track,
    } = req.body ?? {};

    if (
      !peakId ||
      !startedAt ||
      typeof durationSec !== 'number' ||
      typeof trackDistanceKm !== 'number' ||
      !Array.isArray(track) ||
      track.length === 0
    ) {
      return res.status(400).json({
        ok: false,
        error: 'Missing or invalid fields in hike payload',
      });
    }

    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();

      const [result] = await conn.query<ResultSetHeader>(
        `INSERT INTO hikes
           (user_id, peak_id, started_at, duration_sec, track_distance_km, straight_distance_km)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [
          userId,
          Number(peakId),
          new Date(startedAt),
          durationSec,
          trackDistanceKm,
          straightDistanceKm ?? null,
        ],
      );

      const hikeId = result.insertId;

      const values: any[] = [];
      (track as any[]).forEach((p, index) => {
        const lat = Number(p.lat);
        const lng = Number(p.lng);
        if (Number.isFinite(lat) && Number.isFinite(lng)) {
          values.push([hikeId, index, lat, lng]);
        }
      });

      if (values.length > 0) {
        await conn.query(
          `INSERT INTO hike_points (hike_id, seq, lat, lng)
           VALUES ?`,
          [values],
        );
      }

      await conn.commit();

      return res.status(201).json({
        ok: true,
        data: { id: hikeId },
      });
    } catch (e: any) {
      await conn.rollback();
      console.error(e);
      return res.status(500).json({ ok: false, error: e.message });
    } finally {
      conn.release();
    }
  } catch (e: any) {
    console.error(e);
    return res.status(500).json({ ok: false, error: e.message });
  }
});

export default router;
