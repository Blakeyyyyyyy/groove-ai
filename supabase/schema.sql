-- Groove AI — Supabase Database Schema
-- Run this in Supabase SQL Editor: https://supabase.com/dashboard/project/tfbcdcrlhsxvlufmnzdr/sql

-- ============================================
-- TABLES
-- ============================================

-- Users table
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ DEFAULT now(),
  coins INTEGER DEFAULT 150,
  subscription_status TEXT DEFAULT 'free',
  subscription_expires_at TIMESTAMPTZ,
  r2_user_folder TEXT,
  revenuecat_id TEXT UNIQUE
);

-- Videos table
CREATE TABLE IF NOT EXISTS videos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  video_url TEXT NOT NULL,
  thumbnail_url TEXT,
  dance_style TEXT,
  subject_type TEXT,
  status TEXT DEFAULT 'pending'
);

-- Credits log table
CREATE TABLE IF NOT EXISTS credits_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  amount INTEGER NOT NULL,
  type TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  video_id UUID REFERENCES videos(id) ON DELETE SET NULL,
  transaction_id TEXT UNIQUE,
  apple_jws TEXT
);

-- Rate limiting table
CREATE TABLE IF NOT EXISTS generation_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE videos ENABLE ROW LEVEL SECURITY;
ALTER TABLE credits_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE generation_requests ENABLE ROW LEVEL SECURITY;

-- Users policies
CREATE POLICY "Users can read own data" ON users
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Service can insert user" ON users
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Service can update user" ON users
  FOR UPDATE USING (auth.uid() = id);

-- Videos policies
CREATE POLICY "Users can read own videos" ON videos
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Service can insert videos" ON videos
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Service can update videos" ON videos
  FOR UPDATE WITH CHECK (true);

-- Credits log policies
CREATE POLICY "Users can read own credits" ON credits_log
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Service can insert credits" ON credits_log
  FOR INSERT WITH CHECK (true);

-- Generation requests policies
CREATE POLICY "Users can read own requests" ON generation_requests
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Service can insert requests" ON generation_requests
  FOR INSERT WITH CHECK (true);

-- ============================================
-- INDEXES
-- ============================================

CREATE INDEX idx_videos_user_id ON videos (user_id, created_at DESC);
CREATE INDEX idx_credits_user_id ON credits_log (user_id, created_at DESC);
CREATE INDEX idx_credits_transaction_id ON credits_log (transaction_id);
CREATE INDEX idx_gen_requests_user_time ON generation_requests (user_id, created_at DESC);

-- ============================================
-- FUNCTIONS (for atomic credit deduction)
-- ============================================

-- Atomic credit deduction function
CREATE OR REPLACE FUNCTION deduct_coins(
  p_user_id UUID,
  p_amount INTEGER,
  p_video_id UUID DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_current_coins INTEGER;
  v_new_coins INTEGER;
BEGIN
  -- Lock the user row for update
  SELECT coins INTO v_current_coins
  FROM users
  WHERE id = p_user_id
  FOR UPDATE;

  IF v_current_coins IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'User not found');
  END IF;

  IF v_current_coins < p_amount THEN
    RETURN json_build_object('success', false, 'error', 'Insufficient coins', 'coins', v_current_coins);
  END IF;

  v_new_coins := v_current_coins - p_amount;

  UPDATE users SET coins = v_new_coins WHERE id = p_user_id;

  INSERT INTO credits_log (user_id, amount, type, video_id)
  VALUES (p_user_id, -p_amount, 'spent', p_video_id);

  RETURN json_build_object('success', true, 'coins_remaining', v_new_coins);
END;
$$;

-- Refund coins function
CREATE OR REPLACE FUNCTION refund_coins(
  p_user_id UUID,
  p_amount INTEGER,
  p_video_id UUID DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE users SET coins = coins + p_amount WHERE id = p_user_id;

  INSERT INTO credits_log (user_id, amount, type, video_id)
  VALUES (p_user_id, p_amount, 'refund', p_video_id);

  RETURN json_build_object('success', true);
END;
$$;

-- Check rate limits function
CREATE OR REPLACE FUNCTION check_rate_limit(p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_hourly_count INTEGER;
  v_daily_count INTEGER;
BEGIN
  -- Count requests in last hour
  SELECT COUNT(*) INTO v_hourly_count
  FROM generation_requests
  WHERE user_id = p_user_id
    AND created_at > now() - INTERVAL '1 hour';

  -- Count requests in last 24 hours
  SELECT COUNT(*) INTO v_daily_count
  FROM generation_requests
  WHERE user_id = p_user_id
    AND created_at > now() - INTERVAL '24 hours';

  IF v_hourly_count >= 3 THEN
    RETURN json_build_object('allowed', false, 'reason', 'Hourly limit reached (3/hour)', 'hourly', v_hourly_count, 'daily', v_daily_count);
  END IF;

  IF v_daily_count >= 10 THEN
    RETURN json_build_object('allowed', false, 'reason', 'Daily limit reached (10/day)', 'hourly', v_hourly_count, 'daily', v_daily_count);
  END IF;

  -- Log this request
  INSERT INTO generation_requests (user_id) VALUES (p_user_id);

  RETURN json_build_object('allowed', true, 'hourly', v_hourly_count + 1, 'daily', v_daily_count + 1);
END;
$$;

-- Grant subscription coins
CREATE OR REPLACE FUNCTION grant_subscription_coins(
  p_user_id UUID,
  p_amount INTEGER
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE users SET coins = coins + p_amount WHERE id = p_user_id;

  INSERT INTO credits_log (user_id, amount, type)
  VALUES (p_user_id, p_amount, 'subscription_grant');

  RETURN json_build_object('success', true);
END;
$$;
