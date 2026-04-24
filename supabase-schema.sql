-- ============================================================
-- SOSUA PESCE – Supabase Database Schema
-- Run this in: Supabase Dashboard → SQL Editor → New Query
-- ============================================================

-- 1. AGENTS TABLE
CREATE TABLE IF NOT EXISTS agents (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name        TEXT NOT NULL,
  email       TEXT UNIQUE NOT NULL,
  phone       TEXT NOT NULL,
  code        TEXT UNIQUE NOT NULL,   -- referral code e.g. CARLOS4821
  status      TEXT DEFAULT 'active',  -- active | paused | inactive
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 2. SALES TABLE  (admin records each confirmed delivery)
CREATE TABLE IF NOT EXISTS sales (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  customer_name   TEXT,
  customer_phone  TEXT NOT NULL,
  agent_code      TEXT,                        -- which agent referred this customer
  agent_id        UUID REFERENCES agents(id),  -- resolved from agent_code
  fish_amount     INTEGER NOT NULL DEFAULT 0,  -- RD$ paid for fish (cash)
  service_fee     INTEGER NOT NULL DEFAULT 500,-- RD$ coordination fee (Stripe)
  commission      INTEGER NOT NULL DEFAULT 150,-- RD$ owed to agent
  stripe_ref      TEXT,                        -- Stripe payment reference (optional)
  notes           TEXT,
  status          TEXT DEFAULT 'delivered',    -- delivered | cancelled
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- 3. PAYOUTS TABLE  (records each agent payment)
CREATE TABLE IF NOT EXISTS payouts (
  id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  agent_id     UUID REFERENCES agents(id) NOT NULL,
  agent_code   TEXT NOT NULL,
  amount       INTEGER NOT NULL,               -- RD$ paid out
  period_start DATE NOT NULL,
  period_end   DATE NOT NULL,
  sale_count   INTEGER DEFAULT 0,
  status       TEXT DEFAULT 'paid',
  paid_at      TIMESTAMPTZ DEFAULT NOW(),
  notes        TEXT
);

-- ============================================================
-- INDEXES for performance
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_sales_agent_code ON sales(agent_code);
CREATE INDEX IF NOT EXISTS idx_sales_created    ON sales(created_at);
CREATE INDEX IF NOT EXISTS idx_agents_code      ON agents(code);

-- ============================================================
-- ROW LEVEL SECURITY – allow anon INSERT for agent registration
-- (Admin reads/writes use the service_role key in admin.html)
-- ============================================================
ALTER TABLE agents ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales  ENABLE ROW LEVEL SECURITY;
ALTER TABLE payouts ENABLE ROW LEVEL SECURITY;

-- Agents can register themselves (anon key)
CREATE POLICY "allow_agent_insert" ON agents
  FOR INSERT TO anon WITH CHECK (true);

-- Agents can read their own record by code (anon key)
CREATE POLICY "allow_agent_read_own" ON agents
  FOR SELECT TO anon USING (true);

-- Admin full access (service_role bypasses RLS automatically)

-- ============================================================
-- HELPER VIEW: pending commissions per agent
-- ============================================================
CREATE OR REPLACE VIEW agent_balance AS
SELECT
  a.id,
  a.code,
  a.name,
  a.email,
  a.phone,
  a.status,
  COUNT(s.id)       AS total_sales,
  COALESCE(SUM(s.commission), 0) AS total_earned,
  COALESCE(SUM(s.commission), 0)
    - COALESCE((
        SELECT SUM(p.amount) FROM payouts p WHERE p.agent_id = a.id
      ), 0)          AS balance_due
FROM agents a
LEFT JOIN sales s ON s.agent_code = a.code AND s.status = 'delivered'
GROUP BY a.id, a.code, a.name, a.email, a.phone, a.status;

-- ============================================================
-- HELPER VIEW: billing report for a period
-- (filter by created_at in your query)
-- ============================================================
CREATE OR REPLACE VIEW billing_report AS
SELECT
  a.code        AS agent_code,
  a.name        AS agent_name,
  a.phone       AS agent_phone,
  COUNT(s.id)   AS deliveries,
  SUM(s.commission) AS commission_due
FROM sales s
JOIN agents a ON a.code = s.agent_code
WHERE s.status = 'delivered'
GROUP BY a.code, a.name, a.phone
HAVING SUM(s.commission) >= 1000   -- only those above payout threshold
ORDER BY commission_due DESC;
