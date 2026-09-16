const express = require('express');
const router = express.Router();
const db = require('../config/db');

// GET /api/lookups/styles
router.get('/styles', async (req, res, next) => {
  try {
    const [rows] = await db.query('SELECT id, name FROM yoga_styles ORDER BY name');
    res.json({ styles: rows });
  } catch (err) {
    next(err);
  }
});

// GET /api/lookups/cities
router.get('/cities', async (req, res, next) => {
  try {
    const [rows] = await db.query('SELECT id, name FROM cities ORDER BY name');
    res.json({ cities: rows });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
