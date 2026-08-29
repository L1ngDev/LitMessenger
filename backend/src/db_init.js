require('dotenv').config();
const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');

async function init() {
  const conn = await mysql.createConnection({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT) || 3306,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    multipleStatements: true,
  });

  const dbName = process.env.DB_NAME || 'litmobiledb';
  try {
    await conn.query(`CREATE DATABASE IF NOT EXISTS \`${dbName}\``);
  } catch (e) {
    console.warn('Could not CREATE DATABASE (likely no CREATE privilege). Assuming it already exists.');
  }
  await conn.query(`USE \`${dbName}\``);

  // Backward-compatible column additions for existing databases
  const alters = [
    "ALTER TABLE chats ADD COLUMN IF NOT EXISTS type ENUM('private','group') NOT NULL DEFAULT 'private'",
    "ALTER TABLE chats ADD COLUMN IF NOT EXISTS title VARCHAR(128)",
    "ALTER TABLE chats ADD COLUMN IF NOT EXISTS creator_id INT",
  ];
  for (const a of alters) {
    try { await conn.query(a); } catch (e) { console.warn('alter skipped:', e.message); }
  }

  const sql = fs.readFileSync(path.join(__dirname, '..', 'db', 'schema.sql'), 'utf8');
  await conn.query(sql);

  console.log(`Database "${dbName}" initialized.`);
  await conn.end();
}

init().catch((e) => {
  console.error('DB init failed:', e.message);
  process.exit(1);
});
