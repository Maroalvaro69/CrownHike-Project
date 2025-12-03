// backend/src/routes/users.ts
import express from 'express';
import bcrypt from 'bcryptjs';
import { pool } from '../db/pool.js';
import jwt from 'jsonwebtoken';
import { verifyToken } from '../middleware/authMiddleware.js';

const router = express.Router();

// POST /users/register
router.post('/register', async (req, res) => {
  const { username, email, password } = req.body;

  if (!username || !email || !password)
    return res.status(400).json({ ok: false, error: 'Missing fields' });

  try {
    const hashedPassword = await bcrypt.hash(password, 10);

    const [result] = await pool.query(
      'INSERT INTO users (username, email, password) VALUES (?, ?, ?)',
      [username, email, hashedPassword]
    );

    res.status(201).json({ ok: true, userId: (result as any).insertId });
  } catch (err: any) {
    console.error(err);
    res.status(500).json({ ok: false, error: err.message });
  }
});

// POST /users/login
router.post('/login', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password)
    return res.status(400).json({ ok: false, error: 'Missing credentials' });

  const [rows] = await pool.query('SELECT * FROM users WHERE email = ?', [email]);
  const users = rows as any[];
  if (users.length === 0)
    return res.status(404).json({ ok: false, error: 'User not found' });

  const user = users[0];
  const valid = await bcrypt.compare(password, user.password);
  if (!valid)
    return res.status(401).json({ ok: false, error: 'Invalid password' });

  const secret = process.env.JWT_SECRET || 'dev_secret';
  const expiresIn = process.env.JWT_EXPIRES ?? '7d';

  const token = jwt.sign({ sub: user.id, email: user.email }, secret, { expiresIn });

  return res.json({
    ok: true,
    user: { id: user.id, username: user.username, email: user.email },
    token,
  });
});

// PUT /users/me  — aktualizacja profilu (wymaga JWT)
router.put('/me', verifyToken, async (req, res) => {
  try {
    const userId = (req as any).user?.id ?? (req as any).user?.sub;
    if (!userId) {
      return res.status(401).json({ ok: false, error: 'Unauthorized' });
    }

    const { username, allow_location_sharing } = req.body || {};

    const fields: string[] = [];
    const params: any[] = [];

    const push = (col: string, val: any) => {
      fields.push(`${col} = ?`);
      params.push(val);
    };

    if (typeof username === 'string' && username.trim().length > 0) {
      push('username', username.trim());
    }

    if (typeof allow_location_sharing !== 'undefined') {
      push('allow_location_sharing', !!allow_location_sharing ? 1 : 0);
    }

    if (fields.length === 0) {
      return res.status(400).json({ ok: false, error: 'No updatable fields' });
    }

    params.push(Number(userId));
    await pool.query(`UPDATE users SET ${fields.join(', ')} WHERE id = ?`, params);

    return res.json({ ok: true });
  } catch (err: any) {
    console.error(err);
    return res.status(500).json({ ok: false, error: err.message });
  }
});

// GET /users/me — dane podstawowego profilu
router.get('/me', verifyToken, async (req, res) => {
  try {
    const userId = (req as any).user?.id ?? (req as any).user?.sub;
    if (!userId)
      return res.status(401).json({ ok: false, error: 'Unauthorized' });

    const [rows] = await pool.query(
      `SELECT id,
              username,
              email,
              created_at,
              allow_location_sharing
         FROM users
        WHERE id = ?`,
      [Number(userId)]
    );

    const users = rows as any[];
    if (users.length === 0) {
      return res.status(404).json({ ok: false, error: 'User not found' });
    }
    return res.json({ ok: true, data: users[0] });
  } catch (err: any) {
    console.error(err);
    return res.status(500).json({ ok: false, error: err.message });
  }
});
// PUT /users/password – Zmiana hasła
router.put('/password', verifyToken, async (req, res) => {
  const userId = (req as any).user?.id;
  const { oldPassword, newPassword } = req.body;

  if (!oldPassword || !newPassword) {
    return res.status(400).json({ ok: false, error: 'Missing fields' });
  }

  if (newPassword.length < 6) {
    return res.status(400).json({ ok: false, error: 'New password too short' });
  }

  try {
    // 1. Pobierz obecne hasło z bazy
    const [rows] = await pool.query('SELECT password FROM users WHERE id = ?', [userId]);
    const user = (rows as any[])[0];

    if (!user) {
      return res.status(404).json({ ok: false, error: 'User not found' });
    }

    // 2. Sprawdź, czy stare hasło jest poprawne
    const valid = await bcrypt.compare(oldPassword, user.password);
    if (!valid) {
      return res.status(401).json({ ok: false, error: 'Invalid old password' });
    }

    // 3. Zaszyfruj i zapisz nowe hasło
    const newHashed = await bcrypt.hash(newPassword, 10);
    await pool.query('UPDATE users SET password = ? WHERE id = ?', [newHashed, userId]);

    res.json({ ok: true, message: 'Password updated' });
  } catch (err: any) {
    console.error(err);
    res.status(500).json({ ok: false, error: err.message });
  }
});

// DELETE /users/me – Usunięcie konta
router.delete('/me', verifyToken, async (req, res) => {
  const userId = (req as any).user?.id;

  try {
    // Dzięki kluczom obcym w bazie (ON DELETE CASCADE), usunięcie usera 
    // powinno usunąć też jego wędrówki, odznaki itp.
    // Jeśli nie masz CASCADE, musisz najpierw usunąć rekordy z tabel zależnych.
    
    // Zakładamy wersję bezpieczną (kolejność usuwania):
    await pool.query('DELETE FROM user_badges WHERE user_id = ?', [userId]);
    await pool.query('DELETE FROM user_peaks WHERE user_id = ?', [userId]);
    await pool.query('DELETE FROM user_emergency WHERE user_id = ?', [userId]);
    // Wędrówki są bardziej złożone (punkty), ale spróbujmy:
    await pool.query('DELETE FROM hike_points WHERE hike_id IN (SELECT id FROM hikes WHERE user_id = ?)', [userId]);
    await pool.query('DELETE FROM hikes WHERE user_id = ?', [userId]);
    
    // Na koniec sam user
    await pool.query('DELETE FROM users WHERE id = ?', [userId]);

    res.json({ ok: true, message: 'Account deleted' });
  } catch (err: any) {
    console.error(err);
    res.status(500).json({ ok: false, error: err.message });
  }
});
export default router;
