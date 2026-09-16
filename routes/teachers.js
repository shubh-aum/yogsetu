const express = require('express');
const router = express.Router();
const db = require('../config/db');
const { requireRole } = require('../middleware/auth');

const PUBLIC_TEACHER_FIELDS = `
  t.user_id, t.full_name, t.gender, t.years_experience, t.teaching_mode, t.qualifications,
  t.bio, t.profile_photo_url, t.per_session_price, t.trial_price, t.verification_status,
  t.team_rating, c.name AS city
`;

// GET /api/teachers — public directory with optional filters
router.get('/', async (req, res, next) => {
  try {
    const { city, style, mode } = req.query;
    const clauses = ["t.verification_status = 'verified'"];
    const params = [];

    if (city) {
      clauses.push('c.name = ?');
      params.push(city);
    }
    if (mode) {
      clauses.push('t.teaching_mode IN (?, "hybrid")');
      params.push(mode);
    }
    let styleJoin = '';
    if (style) {
      styleJoin = 'JOIN teacher_expertise te ON te.teacher_user_id = t.user_id JOIN yoga_styles ys ON ys.id = te.style_id';
      clauses.push('ys.name = ?');
      params.push(style);
    }

    const [rows] = await db.query(
      `SELECT DISTINCT ${PUBLIC_TEACHER_FIELDS}
       FROM teachers t
       LEFT JOIN cities c ON c.id = t.city_id
       ${styleJoin}
       WHERE ${clauses.join(' AND ')}
       ORDER BY t.team_rating DESC, t.user_id DESC
       LIMIT 100`,
      params
    );
    res.json({ teachers: rows });
  } catch (err) {
    next(err);
  }
});

// GET /api/teachers/:id — public profile
router.get('/:id', async (req, res, next) => {
  try {
    const [rows] = await db.query(
      `SELECT ${PUBLIC_TEACHER_FIELDS}
       FROM teachers t
       LEFT JOIN cities c ON c.id = t.city_id
       WHERE t.user_id = ?`,
      [req.params.id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Teacher not found.' });

    const [expertise] = await db.query(
      `SELECT ys.name FROM teacher_expertise te JOIN yoga_styles ys ON ys.id = te.style_id WHERE te.teacher_user_id = ?`,
      [req.params.id]
    );
    const [ratingRow] = await db.query(
      `SELECT ROUND(AVG(stars), 1) AS avg_rating, COUNT(*) AS rating_count
       FROM ratings WHERE teacher_user_id = ? AND status = 'published'`,
      [req.params.id]
    );

    res.json({
      teacher: rows[0],
      expertise: expertise.map((r) => r.name),
      rating: ratingRow[0],
    });
  } catch (err) {
    next(err);
  }
});

// PUT /api/teachers/me — update own profile
router.put('/me/update', requireRole('teacher'), async (req, res, next) => {
  try {
    const { full_name, gender, years_experience, teaching_mode, qualifications, bio, per_session_price, trial_price } = req.body;

    await db.query(
      `UPDATE teachers SET
        full_name = COALESCE(?, full_name),
        gender = COALESCE(?, gender),
        years_experience = COALESCE(?, years_experience),
        teaching_mode = COALESCE(?, teaching_mode),
        qualifications = COALESCE(?, qualifications),
        bio = COALESCE(?, bio),
        per_session_price = COALESCE(?, per_session_price),
        trial_price = COALESCE(?, trial_price)
       WHERE user_id = ?`,
      [full_name, gender, years_experience, teaching_mode, qualifications, bio, per_session_price, trial_price, req.session.user.id]
    );

    res.json({ message: 'Profile updated.' });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
