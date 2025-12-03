import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';

import { pool } from './db/pool.js';
import usersRouter from './routes/users.js';
import peaksRouter from './routes/peaks.js';
import emergencyRoutes from './routes/emergency.js';
import userPeaksRouter from './routes/userPeaks.js';
import { verifyToken } from './middleware/authMiddleware.js';
import hikesRouter from './routes/hikes.js';
import badgesRoutes from './routes/badges.js';

dotenv.config();

const app = express();
const PORT = Number(process.env.PORT) || 3000;

// middleware
app.use(cors());
app.use(express.json());

// LOGI DIAGNOSTYCZNE – zobaczymy, że montujemy routery
console.log('>>> mounting /peaks routes');
app.use('/peaks', peaksRouter);

console.log('>>> mounting /api/emergency routes');
app.use('/api/emergency', emergencyRoutes);

console.log('>>> mounting /users routes');
app.use('/users', usersRouter);

console.log('>>> mounting / (userPeaks) routes');
app.use('/', userPeaksRouter); // /peaks/:id/mark i /me/peaks

console.log('>>> mounting /hikes routes');
app.use('/hikes', hikesRouter);

console.log('>>> mounting /api/badges routes');
app.use('/api/badges', badgesRoutes);

// TESTOWA TRASA BEZ ROUTERA – żeby sprawdzić ścieżkę /api/badges
app.get('/api/badges-test', (_req, res) => {
  res.json({ ok: true, test: 'badges inline route works' });
});

// testowe endpointy (też przed 404)
app.get('/health', (_req, res) => {
  res.json({
    ok: true,
    service: 'crownhike-api',
    time: new Date().toISOString(),
  });
});

app.get('/db-health', async (_req, res) => {
  try {
    const [rows] = await pool.query('SELECT 1 AS ok');
    res.json({ ok: true, db: rows });
  } catch (e) {
    console.error(e);
    res.status(500).json({ ok: false, error: 'DB not reachable' });
  }
});

app.get('/profile', verifyToken, (req, res) => {
  res.json({
    ok: true,
    message: 'Access granted',
    user: (req as any).user,
  });
});

// 404 NA SAMYM KOŃCU


// start
app.listen(PORT, () => {
  console.log(`[api] running on http://localhost:${PORT}`);
});
