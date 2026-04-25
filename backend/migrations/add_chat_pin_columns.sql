-- Migration: add pin/delete columns to chat_rooms
-- Run this in the Supabase SQL Editor once.

ALTER TABLE chat_rooms
  ADD COLUMN IF NOT EXISTS pinned_by_buyer  BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS pinned_by_seller BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS deleted_by_buyer  BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS deleted_by_seller BOOLEAN NOT NULL DEFAULT FALSE;
