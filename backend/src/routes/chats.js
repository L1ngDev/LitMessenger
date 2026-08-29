const router = require('express').Router();
const pool = require('../db');
const auth = require('../auth');

function mapChatRow(r) {
  const other = r.other_id
    ? { id: r.other_id, username: r.other_username, display_name: r.other_display, avatar: r.other_avatar }
    : null;
  return {
    id: r.id,
    type: r.type,
    title: r.title,
    creator_id: r.creator_id,
    updated_at: r.updated_at,
    last_message: r.last_message,
    other_user: other,
  };
}

// List chats for the current user (private -> other user, group -> title)
router.get('/', auth, async (req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT c.id, c.type, c.title, c.creator_id, c.updated_at,
        (SELECT text FROM messages m WHERE m.chat_id = c.id ORDER BY m.id DESC LIMIT 1) AS last_message,
        CASE WHEN c.type='private' THEN (SELECT u.id FROM users u JOIN chat_members cm2 ON cm2.user_id = u.id WHERE cm2.chat_id = c.id AND u.id <> ? LIMIT 1) ELSE NULL END AS other_id,
        CASE WHEN c.type='private' THEN (SELECT u.username FROM users u JOIN chat_members cm2 ON cm2.user_id = u.id WHERE cm2.chat_id = c.id AND u.id <> ? LIMIT 1) ELSE NULL END AS other_username,
        CASE WHEN c.type='private' THEN (SELECT u.display_name FROM users u JOIN chat_members cm2 ON cm2.user_id = u.id WHERE cm2.chat_id = c.id AND u.id <> ? LIMIT 1) ELSE NULL END AS other_display,
        CASE WHEN c.type='private' THEN (SELECT u.avatar FROM users u JOIN chat_members cm2 ON cm2.user_id = u.id WHERE cm2.chat_id = c.id AND u.id <> ? LIMIT 1) ELSE NULL END AS other_avatar
       FROM chats c
       JOIN chat_members cm ON cm.chat_id = c.id
       WHERE cm.user_id = ?
       ORDER BY c.updated_at DESC`,
      [req.userId, req.userId, req.userId, req.userId, req.userId]
    );
    res.json(rows.map(mapChatRow));
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Create a private (1:1) or group chat
router.post('/', auth, async (req, res) => {
  try {
    const isGroup = req.body.type === 'group' || Array.isArray(req.body.member_ids);
    if (isGroup) {
      const title = (req.body.title || '').toString().trim();
      const memberIds = (req.body.member_ids || [])
        .map(Number)
        .filter((n) => n && n !== req.userId);
      if (!title) return res.status(400).json({ error: 'group title required' });
      if (memberIds.length < 1) return res.status(400).json({ error: 'add at least one member' });

      const [cr] = await pool.query(
        'INSERT INTO chats (type, title, creator_id) VALUES (?, ?, ?)',
        ['group', title, req.userId]
      );
      const chatId = cr.insertId;
      const rows = [[chatId, req.userId], ...memberIds.map((u) => [chatId, u])];
      await pool.query('INSERT INTO chat_members (chat_id, user_id) VALUES ?', [rows]);
      return res.json({ id: chatId });
    }

    const otherId = Number(req.body.with_user_id);
    if (!otherId || otherId === req.userId) {
      return res.status(400).json({ error: 'invalid user' });
    }
    const [u] = await pool.query('SELECT id FROM users WHERE id = ?', [otherId]);
    if (!u.length) return res.status(404).json({ error: 'user not found' });

    const [existing] = await pool.query(
      `SELECT c.id FROM chats c
       JOIN chat_members m1 ON m1.chat_id = c.id AND m1.user_id = ?
       JOIN chat_members m2 ON m2.chat_id = c.id AND m2.user_id = ?
       WHERE c.type = 'private' LIMIT 1`,
      [req.userId, otherId]
    );
    if (existing.length) return res.json({ id: existing[0].id });

    const [cr] = await pool.query("INSERT INTO chats (type) VALUES ('private')");
    const chatId = cr.insertId;
    await pool.query(
      'INSERT INTO chat_members (chat_id, user_id) VALUES (?, ?), (?, ?)',
      [chatId, req.userId, chatId, otherId]
    );
    res.json({ id: chatId });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Global search: users + chats + messages (Telegram-style)
router.get('/search', auth, async (req, res) => {
  try {
    const q = (req.query.q || '').toString();
    const like = `%${q}%`;

    const [users] = await pool.query(
      'SELECT id, username, display_name, avatar FROM users WHERE id <> ? AND (username LIKE ? OR display_name LIKE ?) LIMIT 10',
      [req.userId, like, like]
    );

    const [chats] = await pool.query(
      `SELECT c.id, c.type, c.title, c.creator_id,
        CASE WHEN c.type='private' THEN (SELECT u.id FROM users u JOIN chat_members cm2 ON cm2.user_id = u.id WHERE cm2.chat_id = c.id AND u.id <> ? LIMIT 1) ELSE NULL END AS other_id,
        CASE WHEN c.type='private' THEN (SELECT u.display_name FROM users u JOIN chat_members cm2 ON cm2.user_id = u.id WHERE cm2.chat_id = c.id AND u.id <> ? LIMIT 1) ELSE NULL END AS other_display,
        CASE WHEN c.type='private' THEN (SELECT u.username FROM users u JOIN chat_members cm2 ON cm2.user_id = u.id WHERE cm2.chat_id = c.id AND u.id <> ? LIMIT 1) ELSE NULL END AS other_username
       FROM chats c
       JOIN chat_members cm ON cm.chat_id = c.id
       WHERE cm.user_id = ? AND (
         c.title LIKE ? OR
         (c.type = 'private' AND EXISTS (
           SELECT 1 FROM chat_members cm2 JOIN users u ON u.id = cm2.user_id
           WHERE cm2.chat_id = c.id AND u.id <> ? AND (u.username LIKE ? OR u.display_name LIKE ?)
         ))
       )
       LIMIT 10`,
      [req.userId, req.userId, req.userId, req.userId, like, req.userId, like, like]
    );

    const [messages] = await pool.query(
      `SELECT m.id, m.chat_id, m.sender_id, m.text, m.attachment_url, m.created_at
       FROM messages m
       JOIN chat_members cm ON cm.chat_id = m.chat_id
       WHERE cm.user_id = ? AND m.text LIKE ?
       ORDER BY m.id DESC LIMIT 20`,
      [req.userId, like]
    );

    res.json({
      users,
      chats: chats.map(mapChatRow),
      messages: messages.map((r) => ({
        id: r.id,
        chat_id: r.chat_id,
        sender_id: r.sender_id,
        text: r.text,
        attachment_url: r.attachment_url,
        created_at: r.created_at,
      })),
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Add a member to a chat
router.post('/:id/members', auth, async (req, res) => {
  try {
    const chatId = Number(req.params.id);
    const uid = Number(req.body.user_id);
    const [mem] = await pool.query('SELECT 1 FROM chat_members WHERE chat_id = ? AND user_id = ?', [chatId, req.userId]);
    if (!mem.length) return res.status(403).json({ error: 'forbidden' });
    const [u] = await pool.query('SELECT id FROM users WHERE id = ?', [uid]);
    if (!u.length) return res.status(404).json({ error: 'user not found' });
    await pool.query('INSERT IGNORE INTO chat_members (chat_id, user_id) VALUES (?, ?)', [chatId, uid]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Remove / leave a chat
router.delete('/:id/members/:uid', auth, async (req, res) => {
  try {
    const chatId = Number(req.params.id);
    const uid = Number(req.params.uid);
    const [mem] = await pool.query('SELECT 1 FROM chat_members WHERE chat_id = ? AND user_id = ?', [chatId, req.userId]);
    if (!mem.length) return res.status(403).json({ error: 'forbidden' });
    const [chat] = await pool.query('SELECT creator_id, type FROM chats WHERE id = ?', [chatId]);
    if (!chat.length) return res.status(404).json({ error: 'not found' });
    const isCreator = chat[0].creator_id === req.userId;
    if (uid !== req.userId && !isCreator) return res.status(403).json({ error: 'forbidden' });
    await pool.query('DELETE FROM chat_members WHERE chat_id = ? AND user_id = ?', [chatId, uid]);
    const [rem] = await pool.query('SELECT COUNT(*) c FROM chat_members WHERE chat_id = ?', [chatId]);
    if (rem[0].c === 0) await pool.query('DELETE FROM chats WHERE id = ?', [chatId]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Rename a group (creator only)
router.patch('/:id', auth, async (req, res) => {
  try {
    const chatId = Number(req.params.id);
    const [chat] = await pool.query('SELECT creator_id FROM chats WHERE id = ?', [chatId]);
    if (!chat.length) return res.status(404).json({ error: 'not found' });
    if (chat[0].creator_id !== req.userId) return res.status(403).json({ error: 'only creator can rename' });
    const title = (req.body.title || '').toString().trim();
    if (!title) return res.status(400).json({ error: 'title required' });
    await pool.query('UPDATE chats SET title = ? WHERE id = ?', [title, chatId]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Chat meta (type, title, other_user, members)
router.get('/:id', auth, async (req, res) => {
  try {
    const chatId = Number(req.params.id);
    const [mem] = await pool.query('SELECT 1 FROM chat_members WHERE chat_id = ? AND user_id = ?', [chatId, req.userId]);
    if (!mem.length) return res.status(403).json({ error: 'forbidden' });

    const [rows] = await pool.query(
      `SELECT c.id, c.type, c.title, c.creator_id,
        CASE WHEN c.type='private' THEN (SELECT u.id FROM users u JOIN chat_members cm2 ON cm2.user_id = u.id WHERE cm2.chat_id = c.id AND u.id <> ? LIMIT 1) ELSE NULL END AS other_id,
        CASE WHEN c.type='private' THEN (SELECT u.display_name FROM users u JOIN chat_members cm2 ON cm2.user_id = u.id WHERE cm2.chat_id = c.id AND u.id <> ? LIMIT 1) ELSE NULL END AS other_display,
        CASE WHEN c.type='private' THEN (SELECT u.username FROM users u JOIN chat_members cm2 ON cm2.user_id = u.id WHERE cm2.chat_id = c.id AND u.id <> ? LIMIT 1) ELSE NULL END AS other_username
       FROM chats c WHERE c.id = ?`,
      [req.userId, req.userId, req.userId, chatId]
    );
    if (!rows.length) return res.status(404).json({ error: 'not found' });
    const r = rows[0];
    const [members] = await pool.query(
      'SELECT u.id, u.username, u.display_name, u.avatar FROM users u JOIN chat_members cm ON cm.user_id = u.id WHERE cm.chat_id = ?',
      [chatId]
    );
    res.json({
      id: r.id,
      type: r.type,
      title: r.title,
      creator_id: r.creator_id,
      other_user: r.other_id
        ? { id: r.other_id, username: r.other_username, display_name: r.other_display, avatar: null }
        : null,
      members,
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Get messages in a chat (membership required)
router.get('/:id/messages', auth, async (req, res) => {
  try {
    const chatId = Number(req.params.id);
    const [member] = await pool.query('SELECT 1 FROM chat_members WHERE chat_id = ? AND user_id = ?', [chatId, req.userId]);
    if (!member.length) return res.status(403).json({ error: 'forbidden' });

    const [rows] = await pool.query(
      `SELECT m.id, m.chat_id, m.sender_id, m.text, m.attachment_url, m.created_at,
        (SELECT u.display_name FROM users u WHERE u.id = m.sender_id) AS sender_name,
        (SELECT u.username FROM users u WHERE u.id = m.sender_id) AS sender_username
       FROM messages m WHERE m.chat_id = ? ORDER BY m.id ASC`,
      [chatId]
    );
    res.json(
      rows.map((r) => ({
        id: r.id,
        chat_id: r.chat_id,
        sender_id: r.sender_id,
        text: r.text,
        attachment_url: r.attachment_url,
        created_at: r.created_at,
        sender_name: r.sender_name || r.sender_username,
      }))
    );
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Send a message (text and/or attachment)
router.post('/:id/messages', auth, async (req, res) => {
  try {
    const chatId = Number(req.params.id);
    const { text, attachment_url } = req.body;
    if ((!text || !text.trim()) && !attachment_url) {
      return res.status(400).json({ error: 'empty message' });
    }
    const [member] = await pool.query('SELECT 1 FROM chat_members WHERE chat_id = ? AND user_id = ?', [chatId, req.userId]);
    if (!member.length) return res.status(403).json({ error: 'forbidden' });

    const [r] = await pool.query(
      'INSERT INTO messages (chat_id, sender_id, text, attachment_url) VALUES (?, ?, ?, ?)',
      [chatId, req.userId, (text || '').trim() || null, attachment_url || null]
    );
    const [rows] = await pool.query(
      `SELECT m.id, m.chat_id, m.sender_id, m.text, m.attachment_url, m.created_at,
        (SELECT u.display_name FROM users u WHERE u.id = m.sender_id) AS sender_name,
        (SELECT u.username FROM users u WHERE u.id = m.sender_id) AS sender_username
       FROM messages m WHERE m.id = ?`,
      [r.insertId]
    );
    const x = rows[0];
    res.json({
      id: x.id,
      chat_id: x.chat_id,
      sender_id: x.sender_id,
      text: x.text,
      attachment_url: x.attachment_url,
      created_at: x.created_at,
      sender_name: x.sender_name || x.sender_username,
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
