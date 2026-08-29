require('dotenv').config();
const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const pool = require('./db');

const app = express();
app.use(cors());
app.use(express.json());

const uploadDir = process.env.UPLOAD_DIR || './uploads';
fs.mkdirSync(uploadDir, { recursive: true });

// Static file hosting — uploaded files are reachable at the VDS root /files
app.use('/files', express.static(path.resolve(uploadDir)));

app.get('/', (req, res) => res.json({ service: 'lit-messenger', status: 'ok' }));

app.use('/api', require('./routes/auth'));
app.use('/api/chats', require('./routes/chats'));
app.use('/api/upload', require('./routes/upload'));

app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: 'internal error' });
});

const PORT = Number(process.env.PORT) || 80;
app.listen(PORT, () => console.log(`Lit Messenger backend listening on :${PORT}`));
