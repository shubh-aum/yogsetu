require('dotenv').config();
const express = require('express');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.static(path.join(__dirname, 'public')));

app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'yoga-listing.html'));
});

app.get('/v2', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'yoga-listing-v2.html'));
});

// YogKulam Teacher Directory
app.get('/yoga-teachers', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'yoga-teachers.html'));
});

app.get('/join-teacher', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'join-teacher.html'));
});

app.get('/teacher-login', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'teacher-login.html'));
});

app.get('/teacher/:slug', (req, res) => {
    const slug = req.params.slug;
    const filePath = path.join(__dirname, 'public', `teacher-${slug}.html`);
    res.sendFile(filePath, err => {
        if (err) res.status(404).sendFile(path.join(__dirname, 'public', 'yoga-teachers.html'));
    });
});

// YogKulam Job Portal
app.get('/jobs', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'jobs.html'));
});

app.get('/jobs/:slug', (req, res) => {
    const slug = req.params.slug;
    const filePath = path.join(__dirname, 'public', `job-${slug}.html`);
    res.sendFile(filePath, err => {
        if (err) res.status(404).sendFile(path.join(__dirname, 'public', 'jobs.html'));
    });
});

app.listen(PORT, () => {
    console.log(`Yogsetu server running on http://localhost:${PORT}`);
});
