const express = require('express');
const router = express.Router();
const db = require('../config/db');
const { requireRole } = require('../middleware/auth');

router.use(requireRole('admin'));

// GET /api/admin/teachers?status=pending
router.get('/teachers', async (req, res, next) => {
  try {
    const { status } = req.query;
    const clauses = [];
    const params = [];
    if (status) { clauses.push('t.verification_status = ?'); params.push(status); }

    const [rows] = await db.query(
      `SELECT t.user_id, t.full_name, t.verification_status, u.email, u.status AS account_status
       FROM teachers t JOIN users u ON u.id = t.user_id
       ${clauses.length ? 'WHERE ' + clauses.join(' AND ') : ''}
       ORDER BY t.user_id DESC`,
      params
    );
    res.json({ teachers: rows });
  } catch (err) {
    next(err);
  }
});

// PATCH /api/admin/teachers/:id/verification — approve or reject a teacher
router.patch('/teachers/:id/verification', async (req, res, next) => {
  try {
    const { status } = req.body;
    if (!['verified', 'rejected', 'pending'].includes(status)) {
      return res.status(400).json({ error: 'status must be verified, rejected or pending.' });
    }
    const [result] = await db.query(
      'UPDATE teachers SET verification_status = ? WHERE user_id = ?',
      [status, req.params.id]
    );
    if (!result.affectedRows) return res.status(404).json({ error: 'Teacher not found.' });
    res.json({ message: `Teacher ${status}.` });
  } catch (err) {
    next(err);
  }
});

// PATCH /api/admin/requirements/:id/visibility — pull a requirement off the public board
router.patch('/requirements/:id/visibility', async (req, res, next) => {
  try {
    const { is_visible } = req.body;
    const [result] = await db.query(
      'UPDATE requirements SET is_visible = ? WHERE id = ?',
      [is_visible ? 1 : 0, req.params.id]
    );
    if (!result.affectedRows) return res.status(404).json({ error: 'Requirement not found.' });
    res.json({ message: 'Requirement visibility updated.' });
  } catch (err) {
    next(err);
  }
});

// PATCH /api/admin/users/:id/status — block or reactivate an account
router.patch('/users/:id/status', async (req, res, next) => {
  try {
    const { status } = req.body;
    if (!['active', 'blocked'].includes(status)) {
      return res.status(400).json({ error: 'status must be active or blocked.' });
    }
    const [result] = await db.query('UPDATE users SET status = ? WHERE id = ?', [status, req.params.id]);
    if (!result.affectedRows) return res.status(404).json({ error: 'User not found.' });
    res.json({ message: `User ${status}.` });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
