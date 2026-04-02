const { PrismaClient } = require('@prisma/client');
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const prisma = new PrismaClient();

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_KEY
);

const JWT_SECRET = process.env.JWT_SECRET || 'unimart-secret-key-change-in-production';
const SALT_ROUNDS = 10;

module.exports = { prisma, supabase, JWT_SECRET, SALT_ROUNDS };
