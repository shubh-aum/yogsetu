require('dotenv').config();

const express = require('express');
const path = require('path');
const morgan = require('morgan');

const apiRouter = require('./routes/api');

const app = express();

// Middleware
app.use(morgan('dev'));
app.use(express.urlencoded({ extended: true }));
app.use(express.json());

// JSON API (leads, contact, etc.) — mounted before static so /api/* never falls through to a file lookup
app.use('/api', apiRouter);

// Static site (index.html, teacher pages, job listings, images, css, js)
app.use(express.static(path.join(__dirname, 'public')));

// 404 for anything not matched by static files or the API
app.use((req, res) => {
  res.status(404).sendFile(path.join(__dirname, 'public', '404.html'));
});

// Error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Server error' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`YogSetu server running at http://localhost:${PORT}`);
});
