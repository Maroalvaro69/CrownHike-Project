// src/routes/peaks.ts
import express from 'express';
import { pool } from '../db/pool.js';
import axios from 'axios';
const router = express.Router();

/**
 * GET /peaks — lista szczytów (publiczne)
 *
 * Query params (opcjonalne):
 *  - page  (domyślnie 1, >=1)
 *  - limit (domyślnie 50, maks 200)
 *  - difficulty        ∈ {EASY, MODERATE, HARD, EXPERT}
 *  - main_trail_color  ∈ {RED, BLUE, GREEN, YELLOW, BLACK, MIXED}
 *  - mountain_range    np. 'Tatry Wysokie', 'Tatry Zachodnie', ...
 *  - search            fragment nazwy szczytu (LIKE %search%)
 *  - sort              ∈ {name, height, difficulty}  (domyślnie: height)
 *  - dir               ∈ {asc, desc}                 (domyślnie: desc dla height, w innym wypadku asc)
 *
 * Zwracamy:
 *  - id
 *  - name
 *  - region        (alias z mountain_range)
 *  - elevation_m   (alias z height_m)
 *  - difficulty
 *  - main_trail_color
 *  - lat
 *  - lng
 *  - description
 */
router.get('/', async (req, res) => {
  try {
    const q = req.query as Record<string, string | undefined>;

    // paginacja
    const pageNum = Number(q.page ?? 1);
    const limitNum = Number(q.limit ?? 50);

    const page = Number.isFinite(pageNum) && pageNum > 0 ? pageNum : 1;
    let limit = Number.isFinite(limitNum) && limitNum > 0 ? limitNum : 50;
    if (limit > 200) limit = 200; // bez przesady z ilością ;)

    const offset = (page - 1) * limit;

    // filtry
    const difficulty = q.difficulty?.toString();
    const trailColor = q.main_trail_color?.toString();
    const range = q.mountain_range?.toString();
    const search = q.search?.toString();

    // sortowanie
    const sortRaw = q.sort?.toString() ?? 'height';
    const dirRaw = (q.dir?.toString() ?? '').toLowerCase();

    let sortColumn: string;
    switch (sortRaw) {
      case 'name':
        sortColumn = 'name';
        break;
      case 'difficulty':
        sortColumn = 'difficulty';
        break;
      case 'height':
      default:
        sortColumn = 'height_m';
        break;
    }

    // domyślny kierunek:
    // - jeśli sortujemy po wysokości -> DESC (jak było)
    // - w pozostałych przypadkach -> ASC
    let sortDir: 'ASC' | 'DESC';
    if (dirRaw === 'asc' || dirRaw === 'desc') {
      sortDir = dirRaw === 'desc' ? 'DESC' : 'ASC';
    } else {
      sortDir = sortColumn === 'height_m' ? 'DESC' : 'ASC';
    }

    const where: string[] = [];
    const params: any[] = [];

    if (difficulty) {
      where.push('difficulty = ?');
      params.push(difficulty);
    }

    if (trailColor) {
      where.push('main_trail_color = ?');
      params.push(trailColor);
    }

    if (range) {
      where.push('mountain_range = ?');
      params.push(range);
    }

    if (search) {
      where.push('name LIKE ?');
      params.push(`%${search}%`);
    }

    let sql =
      `SELECT
          id,
          name,
          mountain_range AS region,
          height_m       AS elevation_m,
          difficulty,
          main_trail_color,
          lat,
          lng,
          description
       FROM peaks`;

    if (where.length > 0) {
      sql += ' WHERE ' + where.join(' AND ');
    }

    sql += ` ORDER BY ${sortColumn} ${sortDir}`;
    sql += ` LIMIT ? OFFSET ?`;

    params.push(limit, offset);

    const [rows] = await pool.query(sql, params);
    const list = rows as any[];

    res.json({
      ok: true,
      page,
      limit,
      count: list.length,
      data: list,
    });
  } catch (err: any) {
    console.error(err);
    res
      .status(500)
      .json({ ok: false, error: err?.message ?? 'Internal server error' });
  }
});

/**
 * GET /peaks/:id — szczegóły pojedynczego szczytu (publiczne)
 *
 * Zwracamy:
 *  - id
 *  - name
 *  - region
 *  - elevation_m
 *  - difficulty
 *  - main_trail_color
 *  - lat
 *  - lng
 *  - description
 */
router.get('/:id', async (req, res) => {
  try {
    const id = Number(req.params.id);
    if (!Number.isInteger(id) || id <= 0) {
      return res.status(400).json({ ok: false, error: 'Invalid id' });
    }

    const [rows] = await pool.query(
      `SELECT
          id,
          name,
          mountain_range AS region,
          height_m       AS elevation_m,
          difficulty,
          main_trail_color,
          lat,
          lng,
          description
       FROM peaks
       WHERE id = ?`,
      [id]
    );

    const list = rows as any[];
    if (list.length === 0) {
      return res.status(404).json({ ok: false, error: 'Peak not found' });
    }

    res.json({ ok: true, data: list[0] });
  } catch (err: any) {
    console.error(err);
    res
      .status(500)
      .json({ ok: false, error: err?.message ?? 'Internal server error' });
  }
});
/**
 * GET /peaks/:id/route
 * Wyznacza trasę pieszą (foot-hiking) od użytkownika do szczytu.
 */
router.get('/:id/route', async (req, res) => {
  try {
    const peakId = Number(req.params.id);
    const userLat = Number(req.query.lat);
    const userLng = Number(req.query.lng);

    console.log(`[Backend] Żądanie trasy dla szczytu ID: ${peakId}`);
    console.log(`[Backend] Pozycja startowa: ${userLat}, ${userLng}`);

    // ... (pobieranie szczytu z bazy - bez zmian) ...
    const [rows] = await pool.query(
      'SELECT lat, lng FROM peaks WHERE id = ?',
      [peakId]
    );
    const peak = (rows as any[])[0];

    if (!peak || !peak.lat || !peak.lng) {
      console.log('[Backend] Błąd: Nie znaleziono szczytu w bazie');
      return res.status(404).json({ ok: false, error: 'Peak or coords not found' });
    }

    // SPRAWDZENIE KLUCZA
    const apiKey = process.env.ORS_API_KEY;
    console.log(`[Backend] Klucz API obecny? ${apiKey ? 'TAK (długość: ' + apiKey.length + ')' : 'NIE'}`);

    if (!apiKey) {
      return res.status(500).json({ ok: false, error: 'Server missing ORS key' });
    }

    const orsUrl = 'https://api.openrouteservice.org/v2/directions/foot-hiking/geojson';

    console.log('[Backend] Wysyłanie zapytania do OpenRouteService...');
    
    const response = await axios.post(
      orsUrl,
      {
        coordinates: [
          [userLng, userLat], 
          [peak.lng, peak.lat],
        ],
        // NOWE: Zwiększamy promień poszukiwania drogi
        // -1 oznacza "szukaj tak daleko jak trzeba" (dla startu - userLat/Lng)
        // 5000 oznacza "szukaj w promieniu 5000 metrów" (dla mety - szczytu)
        radiuses: [-1, 5000]
      },
      {
        headers: {
          Authorization: apiKey,
          'Content-Type': 'application/json',
        },
      }
    );

    console.log('[Backend] Odpowiedź z ORS: SUKCES');

    const features = response.data.features;
    if (!features || features.length === 0) {
      return res.status(404).json({ ok: false, error: 'Route not found' });
    }

    const coords = features[0].geometry.coordinates;
    const path = coords.map((p: number[]) => ({ lat: p[1], lng: p[0] }));
    const summary = features[0].properties.summary;

    res.json({
      ok: true,
      data: {
        path,
        distanceM: summary.distance,
        durationS: summary.duration,
      },
    });
  } catch (err: any) {
    // TUTAJ ZOBACZYSZ PRAWDZIWY BŁĄD W KONSOLI
    console.error('!!! ORS ERROR !!!');
    console.error(err.response?.data || err.message);
    
    res.status(500).json({ ok: false, error: 'Failed to fetch route' });
  }
});
export default router;
