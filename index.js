require('dotenv').config();
const express = require('express');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.get('/', (req, res) => {
    res.json({ status: 'ok', project: 'Yogsetu', version: '1.0.0' });
});

app.listen(PORT, () => {
    console.log(`Yogsetu server running on http://localhost:${PORT}`);
});
