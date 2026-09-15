const express = require('express');
const router = express.Router();
const db = require('../config/db');

// Basic phone/whatsapp sanity check
function isValidPhone(v) {
  return typeof v === 'string' && /^[0-9+\-\s]{7,20}$/.test(v.trim());
}

// POST /api/leads — homepage "Free Growth Plan" form
router.post('/leads', async (req, res, next) => {
  try {
    const { name, whatsapp, city, role, plan } = req.body;

    if (!name || !whatsapp || !city || !role) {
      return res.status(400).json({ error: 'name, whatsapp, city and role are required.' });
    }
    if (!isValidPhone(whatsapp)) {
      return res.status(400).json({ error: 'Please enter a valid WhatsApp number.' });
    }

    await db.query(
      'INSERT INTO leads (name, whatsapp, city, role, interested_plan) VALUES (?, ?, ?, ?, ?)',
      [name.trim(), whatsapp.trim(), city.trim(), role.trim(), plan ? plan.trim() : null]
    );

    res.status(201).json({ message: 'Thanks! Our team will reach out on WhatsApp within 24 hrs.' });
  } catch (err) {
    next(err);
  }
});

// POST /api/contact — generic contact / enquiry submissions (jobs, teacher signup, etc.)
router.post('/contact', async (req, res, next) => {
  try {
    const { name, email, phone, message, source_page } = req.body;

    if (!name || (!email && !phone)) {
      return res.status(400).json({ error: 'name and either email or phone are required.' });
    }

    await db.query(
      'INSERT INTO contact_messages (name, email, phone, message, source_page) VALUES (?, ?, ?, ?, ?)',
      [name.trim(), email ? email.trim() : null, phone ? phone.trim() : null, message ? message.trim() : null, source_page || null]
    );

    res.status(201).json({ message: 'Thank you! We will get back to you soon.' });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
