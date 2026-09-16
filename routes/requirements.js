const express = require('express');
const router = express.Router();
const db = require('../config/db');
const { requireRole } = require('../middleware/auth');

async function findCityId(cityName) {
  if (!cityName) return null;
  const [rows] = await db.query('SELECT id FROM cities WHERE name = ? LIMIT 1', [cityName.trim()]);
  return rows.length ? rows[0].id : null;
}

async function findStyleId(styleName) {
  if (!styleName) return null;
  const [rows] = await db.query('SELECT id FROM yoga_styles WHERE name = ? LIMIT 1', [styleName.trim()]);
  return rows.length ? rows[0].id : null;
}

// POST /api/requirements — client posts a new requirement
router.post('/', requireRole('client'), async (req, res, next) => {
  try {
    const { title, style, mode, location, timing, budget_min, budget_max, description } = req.body;

    if (!title) {
      return res.status(400).json({ error: 'title is required.' });
    }

    const styleId = await findStyleId(style);
    const cityId = await findCityId(location);

    const [result] = await db.query(
      `INSERT INTO requirements
        (client_user_id, title, style_id, mode, city_id, area, budget_min, budget_max, description)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        req.session.user.id, title.trim(), styleId, mode || 'either', cityId,
        timing ? timing.trim() : null, budget_min || null, budget_max || null,
        description ? description.trim() : null,
      ]
    );

    res.status(201).json({ id: result.insertId, message: 'Requirement posted.' });
  } catch (err) {
    next(err);
  }
});

// GET /api/requirements — public job board, open + visible only
router.get('/', async (req, res, next) => {
  try {
    const { city, style, mode } = req.query;
    const clauses = ["r.status = 'open'", 'r.is_visible = 1'];
    const params = [];

    if (city) { clauses.push('c.name = ?'); params.push(city); }
    if (mode) { clauses.push('r.mode IN (?, "either")'); params.push(mode); }
    if (style) { clauses.push('ys.name = ?'); params.push(style); }

    const [rows] = await db.query(
      `SELECT r.id, r.title, r.mode, r.budget_min, r.budget_max, r.description, r.created_at,
              c.name AS city, ys.name AS style,
              (SELECT COUNT(*) FROM requirement_applications ra WHERE ra.requirement_id = r.id) AS applicant_count
       FROM requirements r
       LEFT JOIN cities c ON c.id = r.city_id
       LEFT JOIN yoga_styles ys ON ys.id = r.style_id
       WHERE ${clauses.join(' AND ')}
       ORDER BY r.created_at DESC
       LIMIT 100`,
      params
    );
    res.json({ requirements: rows });
  } catch (err) {
    next(err);
  }
});

// GET /api/requirements/:id
router.get('/:id', async (req, res, next) => {
  try {
    const [rows] = await db.query(
      `SELECT r.*, c.name AS city, ys.name AS style
       FROM requirements r
       LEFT JOIN cities c ON c.id = r.city_id
       LEFT JOIN yoga_styles ys ON ys.id = r.style_id
       WHERE r.id = ?`,
      [req.params.id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Requirement not found.' });
    res.json({ requirement: rows[0] });
  } catch (err) {
    next(err);
  }
});

// POST /api/requirements/:id/apply — teacher applies to a requirement
router.post('/:id/apply', requireRole('teacher'), async (req, res, next) => {
  try {
    const [reqRows] = await db.query("SELECT status FROM requirements WHERE id = ?", [req.params.id]);
    if (!reqRows.length) return res.status(404).json({ error: 'Requirement not found.' });
    if (reqRows[0].status !== 'open') return res.status(400).json({ error: 'This requirement is no longer open.' });

    await db.query(
      'INSERT INTO requirement_applications (requirement_id, teacher_user_id) VALUES (?, ?)',
      [req.params.id, req.session.user.id]
    );
    res.status(201).json({ message: 'Application submitted.' });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ error: 'You have already applied to this requirement.' });
    }
    next(err);
  }
});

module.exports = router;
