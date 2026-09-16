const express = require('express');
const router = express.Router();
const db = require('../config/db');
const { requireRole } = require('../middleware/auth');

// POST /api/connections — client requests a teacher directly (direct_browse)
router.post('/', requireRole('client'), async (req, res, next) => {
  try {
    const { teacher_user_id } = req.body;
    if (!teacher_user_id) return res.status(400).json({ error: 'teacher_user_id is required.' });

    const [teacherRows] = await db.query(
      "SELECT user_id FROM teachers WHERE user_id = ? AND verification_status = 'verified'",
      [teacher_user_id]
    );
    if (!teacherRows.length) return res.status(404).json({ error: 'Teacher not found or not yet verified.' });

    await db.query(
      `INSERT INTO connections (client_user_id, teacher_user_id, origin) VALUES (?, ?, 'direct_browse')`,
      [req.session.user.id, teacher_user_id]
    );
    res.status(201).json({ message: 'Request sent to the teacher.' });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ error: 'You already have a connection with this teacher.' });
    }
    next(err);
  }
});

// GET /api/connections — list the caller's own connections (client or teacher)
router.get('/', async (req, res, next) => {
  try {
    if (!req.session.user) return res.status(401).json({ error: 'Please log in.' });
    const { role, id } = req.session.user;
    const column = role === 'teacher' ? 'teacher_user_id' : 'client_user_id';

    const [rows] = await db.query(
      `SELECT conn.id, conn.status, conn.origin, conn.requested_at, conn.decided_at,
              cu.full_name AS client_name, tu.full_name AS teacher_name
       FROM connections conn
       LEFT JOIN clients cu ON cu.user_id = conn.client_user_id
       LEFT JOIN teachers tu ON tu.user_id = conn.teacher_user_id
       WHERE conn.${column} = ?
       ORDER BY conn.requested_at DESC`,
      [id]
    );
    res.json({ connections: rows });
  } catch (err) {
    next(err);
  }
});

// PATCH /api/connections/:id — teacher approves or declines a pending connection
router.patch('/:id', requireRole('teacher'), async (req, res, next) => {
  try {
    const { action, decline_reason } = req.body;
    if (!['approve', 'decline'].includes(action)) {
      return res.status(400).json({ error: 'action must be approve or decline.' });
    }

    const [rows] = await db.query(
      'SELECT id, status FROM connections WHERE id = ? AND teacher_user_id = ?',
      [req.params.id, req.session.user.id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Connection not found.' });
    if (rows[0].status !== 'pending') return res.status(400).json({ error: 'This connection has already been decided.' });

    const newStatus = action === 'approve' ? 'approved' : 'declined';
    await db.query(
      `UPDATE connections SET status = ?, decline_reason = ?, decided_at = NOW(),
        whatsapp_shared_at = IF(? = 'approved', NOW(), whatsapp_shared_at)
       WHERE id = ?`,
      [newStatus, action === 'decline' ? (decline_reason || null) : null, newStatus, req.params.id]
    );
    res.json({ message: `Connection ${newStatus}.` });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
