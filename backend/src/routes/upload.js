const router = require('express').Router();
const multer = require('multer');
const fs = require('fs');
const path = require('path');
const auth = require('../auth');

const uploadDir = process.env.UPLOAD_DIR || './uploads';
fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || '';
    cb(null, Date.now() + '_' + Math.round(Math.random() * 1e9) + ext);
  },
});

const upload = multer({ storage, limits: { fileSize: 25 * 1024 * 1024 } });

router.post('/', auth, upload.single('file'), (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'no file' });
  const base = (process.env.PUBLIC_BASE_URL || '').replace(/\/$/, '');
  res.json({ url: `${base}/files/${req.file.filename}` });
});

module.exports = router;
