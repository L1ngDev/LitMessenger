-- Lit Messenger database schema
-- Run against the `litmobiledb` database (db_init.js does this automatically).

CREATE TABLE IF NOT EXISTS users (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  username      VARCHAR(64)  NOT NULL UNIQUE,
  password_hash VARCHAR(100) NOT NULL,
  display_name  VARCHAR(128),
  avatar        VARCHAR(255),
  created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS chats (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  type       ENUM('private', 'group') NOT NULL DEFAULT 'private',
  title      VARCHAR(128),
  creator_id INT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS chat_members (
  chat_id INT NOT NULL,
  user_id INT NOT NULL,
  PRIMARY KEY (chat_id, user_id),
  FOREIGN KEY (chat_id) REFERENCES chats(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS messages (
  id             INT AUTO_INCREMENT PRIMARY KEY,
  chat_id        INT NOT NULL,
  sender_id      INT NOT NULL,
  text           TEXT,
  attachment_url VARCHAR(512),
  created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (chat_id)   REFERENCES chats(id)  ON DELETE CASCADE,
  FOREIGN KEY (sender_id) REFERENCES users(id)  ON DELETE CASCADE
);

CREATE INDEX idx_messages_chat ON messages(chat_id, id);
