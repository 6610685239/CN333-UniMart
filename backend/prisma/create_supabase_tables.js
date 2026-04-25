require('dotenv').config();
const { Client } = require('pg');

const sql = `
-- 1. chat_rooms
CREATE TABLE IF NOT EXISTS chat_rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  buyer_id UUID NOT NULL REFERENCES users(id),
  seller_id UUID NOT NULL REFERENCES users(id),
  product_id INTEGER NOT NULL REFERENCES "Product"(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(buyer_id, seller_id, product_id)
);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_buyer ON chat_rooms(buyer_id);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_seller ON chat_rooms(seller_id);

-- 2. chat_messages
CREATE TABLE IF NOT EXISTS chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES users(id),
  content TEXT,
  image_url TEXT,
  type VARCHAR(10) NOT NULL DEFAULT 'text' CHECK (type IN ('text', 'image')),
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_chat_messages_room ON chat_messages(room_id, created_at);
CREATE INDEX IF NOT EXISTS idx_chat_messages_unread ON chat_messages(room_id, is_read) WHERE is_read = FALSE;

-- 3. chat_reports
CREATE TABLE IF NOT EXISTS chat_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES chat_rooms(id),
  reporter_id UUID NOT NULL REFERENCES users(id),
  reported_user_id UUID NOT NULL REFERENCES users(id),
  reason TEXT NOT NULL,
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'resolved')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. notifications
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  type VARCHAR(30) NOT NULL CHECK (type IN ('chat_message', 'transaction_update', 'review_received')),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB DEFAULT '{}',
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(user_id, is_read) WHERE is_read = FALSE;

-- 5. notification_settings
CREATE TABLE IF NOT EXISTS notification_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) UNIQUE,
  push_enabled BOOLEAN DEFAULT TRUE,
  chat_notifications BOOLEAN DEFAULT TRUE,
  transaction_notifications BOOLEAN DEFAULT TRUE,
  fcm_token TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
`;

async function main() {
  // Use DATABASE_URL (pooler, port 6543) — strip pgbouncer param for DDL
  const connStr = (process.env.DATABASE_URL || process.env.DIRECT_URL)
    .replace('pgbouncer=true&', '')
    .replace('&pgbouncer=true', '')
    .replace('?pgbouncer=true', '?');
  const client = new Client({
    connectionString: connStr,
    ssl: { rejectUnauthorized: false },
  });
  await client.connect();
  console.log('Connected to Supabase Postgres');
  await client.query(sql);
  console.log('All 5 Supabase-managed tables created successfully');
  await client.end();
}

main().catch((e) => {
  console.error('FAILED:', e.message);
  process.exit(1);
});
