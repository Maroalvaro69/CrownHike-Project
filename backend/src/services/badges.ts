// backend/src/services/badges.ts
import { pool } from '../db/pool.js';

export type BadgeRow = {
  id: number;
  code: string;
  name: string;
  description: string | null;
  required_peaks: number;
};

/**
 * Przyznaje użytkownikowi brakujące odznaki na podstawie liczby
 * różnych zdobytych szczytów (TATRA_1, TATRA_3 itd.).
 * Zwraca listę NOWO przyznanych odznak.
 */
export async function awardBadgesForUser(userId: number): Promise<BadgeRow[]> {
  // 1. ile różnych szczytów ma user
  const [[{ count }]] = await pool.query(
    `SELECT COUNT(DISTINCT peak_id) AS count
       FROM user_peaks
      WHERE user_id = ?`,
    [userId]
  ) as any;

  // 2. jakie odznaki spełnia, a jeszcze ich nie ma
  const [rows] = await pool.query(
    `SELECT b.id, b.code, b.name, b.description, b.required_peaks
       FROM badges b
      WHERE b.required_peaks <= ?
        AND b.id NOT IN (
          SELECT badge_id FROM user_badges WHERE user_id = ?
        )`,
    [count, userId]
  );

  const badgesToInsert = rows as BadgeRow[];

  if (badgesToInsert.length === 0) {
    return [];
  }

  // 3. zapis odznak do user_badges
  const values = badgesToInsert.map((b) => [userId, b.id]);

  await pool.query(
    `INSERT INTO user_badges (user_id, badge_id) VALUES ?`,
    [values]
  );

  // 4. zwracamy listę nowo przyznanych odznak
  return badgesToInsert;
}

/**
 * Nadaje konkretną odznakę po jej kodzie, jeśli użytkownik jej jeszcze nie ma.
 * Zwraca true, jeśli odznaka została NOWO przyznana.
 */
export async function awardBadgeByCode(
  userId: number,
  badgeCode: string
): Promise<boolean> {
  // znajdź odznakę po kodzie
  const [[badge]] = await pool.query(
    `SELECT id FROM badges WHERE code = ?`,
    [badgeCode]
  ) as any;

  if (!badge) {
    console.warn(`Badge with code ${badgeCode} not found`);
    return false;
  }

  const badgeId = badge.id as number;

  // sprawdź, czy user już ją ma
  const [[exists]] = await pool.query(
    `SELECT id FROM user_badges WHERE user_id = ? AND badge_id = ?`,
    [userId, badgeId]
  ) as any;

  if (exists) {
    return false; // już miał tę odznakę
  }

  // nadaj odznakę
  await pool.query(
    `INSERT INTO user_badges (user_id, badge_id) VALUES (?, ?)`,
    [userId, badgeId]
  );

  return true;
}
