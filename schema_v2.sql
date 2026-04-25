-- ============================================================
-- REFERRAL PLATFORM v2.0 – Generisches Schema
-- Multi-Tenant | Multi-Produkt | Multi-Provisions-Modell
-- ============================================================

-- ── EXTENSIONS ──────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_cron";

-- ============================================================
-- 1. PLATTFORM
-- ============================================================
CREATE TABLE IF NOT EXISTS platform_settings (
  id                    UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name                  TEXT NOT NULL DEFAULT 'Referral Platform',
  owner_email           TEXT,
  owner_phone           TEXT,
  default_currency      TEXT DEFAULT 'RD$',
  created_at            TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO platform_settings (name, owner_email, owner_phone)
VALUES ('Sosua Pesce Platform', 'office@ynhald.com', '+18299758857')
ON CONFLICT DO NOTHING;

-- ============================================================
-- 2. HÄNDLER (MERCHANTS)
-- ============================================================
CREATE TABLE IF NOT EXISTS merchants (
  id                    UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  slug                  TEXT UNIQUE NOT NULL,   -- URL-Name z.B. "sosuapesce"
  name                  TEXT NOT NULL,
  description           TEXT,
  category              TEXT,                   -- fish | massage | handwerk | ...
  logo_url              TEXT,
  whatsapp_number       TEXT,
  email                 TEXT,
  phone                 TEXT,
  address               TEXT,
  city                  TEXT,
  country               TEXT DEFAULT 'DO',
  currency              TEXT DEFAULT 'RD$',
  language              TEXT DEFAULT 'es',      -- default language
  stripe_link           TEXT,                   -- default Stripe payment link

  -- Plattformgebühr (was Händler an Plattform zahlt)
  platform_fee_type     TEXT DEFAULT 'fixed',   -- fixed | percentage
  platform_fee_value    NUMERIC DEFAULT 0,      -- Betrag oder Prozent
  base_fee              NUMERIC DEFAULT 0,      -- monatliche Grundgebühr

  -- Admin-Zugang für Händler
  admin_password        TEXT,                   -- gehashtes Passwort

  status                TEXT DEFAULT 'active',  -- active | paused | inactive
  created_at            TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 3. PRODUKTE (pro Händler)
-- ============================================================
CREATE TABLE IF NOT EXISTS merchant_products (
  id                    UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  merchant_id           UUID REFERENCES merchants(id) ON DELETE CASCADE,

  -- Grunddaten
  name                  TEXT NOT NULL,
  description           TEXT,
  category              TEXT,
  image_url             TEXT,
  sort_order            INTEGER DEFAULT 0,
  is_featured           BOOLEAN DEFAULT false,

  -- Preis-Modell
  price_type            TEXT DEFAULT 'fixed',
  -- fixed | per_unit | variable | negotiated | free
  price                 NUMERIC DEFAULT 0,
  price_unit            TEXT,                   -- kg | hour | person | piece | session
  price_min             NUMERIC,               -- bei variable
  price_max             NUMERIC,               -- bei variable
  currency              TEXT DEFAULT 'RD$',

  -- Service-/Koordinationsgebühr
  service_fee_type      TEXT DEFAULT 'none',   -- fixed | percentage | none
  service_fee           NUMERIC DEFAULT 0,

  -- Zahlung
  payment_method        TEXT DEFAULT 'hybrid', -- online | cash | hybrid | any
  stripe_link           TEXT,                  -- produktspezifischer Stripe-Link

  -- Lieferung / Erfüllung
  fulfillment_type      TEXT DEFAULT 'delivery',
  -- delivery | pickup | onsite | digital | appointment
  delivery_fee          NUMERIC DEFAULT 0,
  delivery_area         TEXT,

  -- Provision für Agenten
  commission_type       TEXT DEFAULT 'fixed',  -- fixed | percentage | points | hybrid | none
  commission_value      NUMERIC DEFAULT 0,     -- Betrag oder Prozent
  commission_points     INTEGER DEFAULT 0,     -- Punkte bei hybrid
  commission_base       TEXT DEFAULT 'sale_amount',
  -- sale_amount | service_fee | total
  commission_recurring  BOOLEAN DEFAULT true,  -- auch bei Folge-Käufen?
  commission_min_order  NUMERIC DEFAULT 0,     -- Mindestbestellwert für Provision

  -- Abonnement
  is_subscription       BOOLEAN DEFAULT false,
  subscription_interval TEXT,                  -- weekly | monthly | yearly

  -- Verfügbarkeit
  stock_type            TEXT DEFAULT 'unlimited',
  -- unlimited | limited | seasonal | on_request
  available_quantity    INTEGER,
  available_from        DATE,
  available_until       DATE,

  status                TEXT DEFAULT 'active', -- active | draft | archived
  created_at            TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 4. PROVISIONS-REGELN (pro Händler)
-- ============================================================
CREATE TABLE IF NOT EXISTS merchant_commission_rules (
  id                         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  merchant_id                UUID REFERENCES merchants(id) ON DELETE CASCADE,

  -- Mindest-Neukunden pro Monat um aktiv zu bleiben
  min_new_customers_per_month INTEGER DEFAULT 1,

  -- Was passiert bei Pause (wir haben Modell A gewählt)
  pause_commission_action     TEXT DEFAULT 'accumulate',
  -- accumulate | forfeit | forfeit_after_30

  -- Nach wie vielen Monaten Pause → frozen
  freeze_after_months         INTEGER DEFAULT 3,

  -- Mindestbetrag für Auszahlung
  min_payout_amount           NUMERIC DEFAULT 1000,

  -- Abrechnungsperioden
  payout_schedule             TEXT DEFAULT 'bimonthly',
  -- weekly | bimonthly | monthly

  -- Punkte-System (falls verwendet)
  points_enabled              BOOLEAN DEFAULT false,
  points_per_currency_unit    NUMERIC DEFAULT 1,   -- 1 Punkt pro RD$
  points_redemption_rate      NUMERIC DEFAULT 100, -- 100 Punkte = 1 RD$
  points_expiry_days          INTEGER DEFAULT 0,   -- 0 = kein Verfall

  -- Definition Neukunde
  new_customer_definition     TEXT DEFAULT 'never_bought',
  -- never_bought | not_in_6_months | any_via_link

  created_at                  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 5. AGENTEN
-- ============================================================
CREATE TABLE IF NOT EXISTS agents (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name        TEXT NOT NULL,
  email       TEXT UNIQUE NOT NULL,
  phone       TEXT NOT NULL,
  status      TEXT DEFAULT 'active', -- global status
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Verbindung Agent ↔ Händler (ein Agent kann mehrere Händler haben)
CREATE TABLE IF NOT EXISTS agent_merchant_links (
  id                    UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  agent_id              UUID REFERENCES agents(id) ON DELETE CASCADE,
  merchant_id           UUID REFERENCES merchants(id) ON DELETE CASCADE,
  UNIQUE (agent_id, merchant_id),

  ref_code              TEXT UNIQUE NOT NULL,  -- z.B. "CARLOS-FISCHER"

  status                TEXT DEFAULT 'pending',
  -- pending | active | paused | frozen | inactive | banned

  -- Zeitstempel für Status-Tracking
  activated_at          TIMESTAMPTZ,
  paused_at             TIMESTAMPTZ,
  frozen_at             TIMESTAMPTZ,

  -- Pause-Tracking
  pause_count           INTEGER DEFAULT 0,       -- wie oft pausiert
  consecutive_pauses    INTEGER DEFAULT 0,       -- Monate in Folge pausiert
  last_new_customer_at  TIMESTAMPTZ,            -- letzter Neukunde

  -- Statistiken (denormalisiert für Performance)
  new_customers_count   INTEGER DEFAULT 0,
  total_sales_count     INTEGER DEFAULT 0,
  total_earned          NUMERIC DEFAULT 0,       -- gesamt verdient
  total_paid            NUMERIC DEFAULT 0,       -- davon ausgezahlt
  accumulated_amount    NUMERIC DEFAULT 0,       -- aufgestaut während Pause
  points_balance        INTEGER DEFAULT 0,       -- aktuelles Punkteguthaben
  points_redeemed       INTEGER DEFAULT 0,       -- eingelöste Punkte

  created_at            TIMESTAMPTZ DEFAULT NOW()
);

-- Monatliche Status-Historie pro Agent+Händler
CREATE TABLE IF NOT EXISTS agent_status_history (
  id                    UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  agent_id              UUID REFERENCES agents(id),
  merchant_id           UUID REFERENCES merchants(id),
  link_id               UUID REFERENCES agent_merchant_links(id),

  month                 DATE NOT NULL,           -- z.B. 2025-04-01
  status_start          TEXT,
  status_end            TEXT,
  new_customers         INTEGER DEFAULT 0,
  sales_count           INTEGER DEFAULT 0,
  commission_earned     NUMERIC DEFAULT 0,
  commission_paid       NUMERIC DEFAULT 0,
  commission_accumulated NUMERIC DEFAULT 0,

  created_at            TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 6. KUNDEN (für Neukunden-Erkennung)
-- ============================================================
CREATE TABLE IF NOT EXISTS customers (
  id                    UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  merchant_id           UUID REFERENCES merchants(id) ON DELETE CASCADE,
  phone                 TEXT NOT NULL,
  name                  TEXT,
  first_purchase_at     TIMESTAMPTZ DEFAULT NOW(),
  total_purchases       INTEGER DEFAULT 0,
  total_spent           NUMERIC DEFAULT 0,
  agent_id              UUID REFERENCES agents(id),  -- wer hat ihn gebracht
  ref_code              TEXT,
  created_at            TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (merchant_id, phone)  -- ein Kunde pro Händler eindeutig über Telefon
);

-- ============================================================
-- 7. VERKÄUFE / TRANSAKTIONEN
-- ============================================================
CREATE TABLE IF NOT EXISTS sales (
  id                    UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  merchant_id           UUID REFERENCES merchants(id),
  product_id            UUID REFERENCES merchant_products(id),
  customer_id           UUID REFERENCES customers(id),
  agent_id              UUID REFERENCES agents(id),
  link_id               UUID REFERENCES agent_merchant_links(id),
  ref_code              TEXT,

  -- Beträge
  sale_amount           NUMERIC NOT NULL DEFAULT 0,  -- was Kunde zahlt
  service_fee           NUMERIC DEFAULT 0,           -- Koordinationsgebühr
  platform_fee          NUMERIC DEFAULT 0,           -- Plattformgebühr
  commission_amount     NUMERIC DEFAULT 0,           -- Agentenprovision (RD$)
  commission_points     INTEGER DEFAULT 0,           -- Agentenprovision (Punkte)
  merchant_revenue      NUMERIC DEFAULT 0,           -- was beim Händler bleibt
  commission_type       TEXT,                        -- snapshot des Modells
  is_new_customer       BOOLEAN DEFAULT false,       -- war das ein Neukunde?

  -- Zahlung
  payment_method        TEXT,
  stripe_ref            TEXT,

  -- Details
  customer_name         TEXT,
  customer_phone        TEXT,
  notes                 TEXT,
  status                TEXT DEFAULT 'delivered',    -- delivered | cancelled

  created_at            TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 8. PUNKTE-LEDGER
-- ============================================================
CREATE TABLE IF NOT EXISTS points_ledger (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  agent_id        UUID REFERENCES agents(id),
  merchant_id     UUID REFERENCES merchants(id),
  link_id         UUID REFERENCES agent_merchant_links(id),
  sale_id         UUID REFERENCES sales(id),

  points_change   INTEGER NOT NULL,  -- positiv = verdient, negativ = eingelöst
  balance_after   INTEGER NOT NULL,
  type            TEXT,              -- earned | redeemed | expired | adjusted
  notes           TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 9. AUSZAHLUNGEN
-- ============================================================
CREATE TABLE IF NOT EXISTS payouts (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  agent_id        UUID REFERENCES agents(id),
  merchant_id     UUID REFERENCES merchants(id),
  link_id         UUID REFERENCES agent_merchant_links(id),

  amount          NUMERIC NOT NULL,
  currency        TEXT DEFAULT 'RD$',
  period_start    DATE NOT NULL,
  period_end      DATE NOT NULL,
  sale_count      INTEGER DEFAULT 0,
  includes_accumulated BOOLEAN DEFAULT false,  -- enthält aufgestaute Beträge?

  payout_method   TEXT DEFAULT 'cash',  -- cash | transfer | stripe
  status          TEXT DEFAULT 'paid',
  paid_at         TIMESTAMPTZ DEFAULT NOW(),
  notes           TEXT
);

-- Plattformgebühren (was Händler an Plattform zahlt)
CREATE TABLE IF NOT EXISTS platform_payouts (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  merchant_id     UUID REFERENCES merchants(id),
  amount          NUMERIC NOT NULL,
  period_start    DATE NOT NULL,
  period_end      DATE NOT NULL,
  transaction_count INTEGER DEFAULT 0,
  base_fee        NUMERIC DEFAULT 0,
  transaction_fees NUMERIC DEFAULT 0,
  status          TEXT DEFAULT 'pending',  -- pending | paid
  paid_at         TIMESTAMPTZ,
  notes           TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 10. INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_sales_merchant    ON sales(merchant_id);
CREATE INDEX IF NOT EXISTS idx_sales_agent       ON sales(agent_id);
CREATE INDEX IF NOT EXISTS idx_sales_created     ON sales(created_at);
CREATE INDEX IF NOT EXISTS idx_sales_ref         ON sales(ref_code);
CREATE INDEX IF NOT EXISTS idx_agents_email      ON agents(email);
CREATE INDEX IF NOT EXISTS idx_aml_ref           ON agent_merchant_links(ref_code);
CREATE INDEX IF NOT EXISTS idx_aml_status        ON agent_merchant_links(status);
CREATE INDEX IF NOT EXISTS idx_customers_phone   ON customers(merchant_id, phone);
CREATE INDEX IF NOT EXISTS idx_points_agent      ON points_ledger(agent_id, merchant_id);

-- ============================================================
-- 11. ROW LEVEL SECURITY
-- ============================================================
ALTER TABLE merchants               ENABLE ROW LEVEL SECURITY;
ALTER TABLE merchant_products       ENABLE ROW LEVEL SECURITY;
ALTER TABLE merchant_commission_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE agents                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_merchant_links    ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_status_history    ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers               ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE points_ledger           ENABLE ROW LEVEL SECURITY;
ALTER TABLE payouts                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform_payouts        ENABLE ROW LEVEL SECURITY;

-- Öffentlich lesbar (für Landingpages)
CREATE POLICY "public_read_merchants"   ON merchants             FOR SELECT TO anon USING (status = 'active');
CREATE POLICY "public_read_products"    ON merchant_products     FOR SELECT TO anon USING (status = 'active');
CREATE POLICY "public_read_commission"  ON merchant_commission_rules FOR SELECT TO anon USING (true);

-- Agenten können sich selbst registrieren
CREATE POLICY "agent_insert"            ON agents                FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "agent_read"              ON agents                FOR SELECT TO anon USING (true);
CREATE POLICY "aml_insert"             ON agent_merchant_links  FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "aml_read"               ON agent_merchant_links  FOR SELECT TO anon USING (true);

-- Kunden: anon kann lesen und einfügen (für Neukunden-Check)
CREATE POLICY "customer_insert"         ON customers             FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "customer_read"           ON customers             FOR SELECT TO anon USING (true);

-- Punkte: anon kann lesen
CREATE POLICY "points_read"             ON points_ledger         FOR SELECT TO anon USING (true);

-- Sales: anon kann lesen (für Agent-Dashboard)
CREATE POLICY "sales_read"              ON sales                 FOR SELECT TO anon USING (true);
CREATE POLICY "payouts_read"            ON payouts               FOR SELECT TO anon USING (true);

-- ============================================================
-- 12. AUTOMATIK: Monatliche Status-Prüfung (pg_cron)
-- ============================================================
CREATE OR REPLACE FUNCTION check_agent_activity()
RETURNS void AS $$
DECLARE
  link RECORD;
  rule RECORD;
  new_customers_this_month INTEGER;
  this_month DATE := date_trunc('month', NOW())::DATE;
  last_month DATE := (date_trunc('month', NOW()) - INTERVAL '1 month')::DATE;
BEGIN
  -- Für jeden aktiven/pausierten Agent-Händler-Link
  FOR link IN
    SELECT aml.*, m.id as mid
    FROM agent_merchant_links aml
    JOIN merchants m ON m.id = aml.merchant_id
    WHERE aml.status IN ('active', 'paused')
  LOOP
    -- Lade Provisionsregeln des Händlers
    SELECT * INTO rule
    FROM merchant_commission_rules
    WHERE merchant_id = link.merchant_id
    LIMIT 1;

    IF rule IS NULL THEN
      CONTINUE;
    END IF;

    -- Zähle Neukunden im letzten Monat
    SELECT COUNT(*) INTO new_customers_this_month
    FROM sales s
    JOIN customers c ON c.id = s.customer_id
    WHERE s.agent_id = link.agent_id
      AND s.merchant_id = link.merchant_id
      AND s.is_new_customer = true
      AND s.created_at >= last_month
      AND s.created_at < this_month
      AND s.status = 'delivered';

    -- Status-Entscheidung
    IF new_customers_this_month >= rule.min_new_customers_per_month THEN
      -- Agent hat Ziel erreicht → aktiv
      UPDATE agent_merchant_links SET
        status = 'active',
        consecutive_pauses = 0,
        last_new_customer_at = NOW()
      WHERE id = link.id;

    ELSE
      -- Agent hat Ziel NICHT erreicht → pausieren
      UPDATE agent_merchant_links SET
        status = 'paused',
        paused_at = NOW(),
        pause_count = pause_count + 1,
        consecutive_pauses = consecutive_pauses + 1
      WHERE id = link.id;

      -- Nach X Monaten → frozen
      IF link.consecutive_pauses + 1 >= rule.freeze_after_months THEN
        UPDATE agent_merchant_links SET
          status = 'frozen',
          frozen_at = NOW()
        WHERE id = link.id;
      END IF;
    END IF;

    -- Status-Historie speichern
    INSERT INTO agent_status_history (
      agent_id, merchant_id, link_id, month,
      status_start, status_end, new_customers
    ) VALUES (
      link.agent_id, link.merchant_id, link.id, last_month,
      link.status,
      CASE WHEN new_customers_this_month >= COALESCE(rule.min_new_customers_per_month, 1)
           THEN 'active' ELSE 'paused' END,
      new_customers_this_month
    )
    ON CONFLICT DO NOTHING;

  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Cron-Job: läuft am 1. jedes Monats um 00:01 Uhr
SELECT cron.schedule(
  'monthly-agent-check',
  '1 0 1 * *',
  'SELECT check_agent_activity();'
);

-- ============================================================
-- 13. FUNKTION: Provision automatisch berechnen bei Verkauf
-- ============================================================
CREATE OR REPLACE FUNCTION calculate_sale_amounts(
  p_product_id UUID,
  p_merchant_id UUID,
  p_sale_amount NUMERIC,
  p_agent_id UUID DEFAULT NULL
)
RETURNS TABLE (
  service_fee       NUMERIC,
  platform_fee      NUMERIC,
  commission_amount NUMERIC,
  commission_points INTEGER,
  merchant_revenue  NUMERIC,
  commission_type   TEXT
) AS $$
DECLARE
  prod RECORD;
  rule RECORD;
  merch RECORD;
  v_service_fee     NUMERIC := 0;
  v_platform_fee    NUMERIC := 0;
  v_commission      NUMERIC := 0;
  v_points          INTEGER := 0;
  v_comm_type       TEXT := 'none';
BEGIN
  -- Produkt laden
  SELECT * INTO prod FROM merchant_products WHERE id = p_product_id;
  -- Händler laden
  SELECT * INTO merch FROM merchants WHERE id = p_merchant_id;
  -- Provisionsregeln laden
  SELECT * INTO rule FROM merchant_commission_rules WHERE merchant_id = p_merchant_id LIMIT 1;

  -- Service Fee berechnen
  IF prod.service_fee_type = 'fixed' THEN
    v_service_fee := prod.service_fee;
  ELSIF prod.service_fee_type = 'percentage' THEN
    v_service_fee := ROUND(p_sale_amount * prod.service_fee / 100, 2);
  END IF;

  -- Plattformgebühr berechnen
  IF merch.platform_fee_type = 'fixed' THEN
    v_platform_fee := merch.platform_fee_value;
  ELSIF merch.platform_fee_type = 'percentage' THEN
    v_platform_fee := ROUND(p_sale_amount * merch.platform_fee_value / 100, 2);
  END IF;

  -- Agentenprovision berechnen (nur wenn Agent vorhanden)
  IF p_agent_id IS NOT NULL THEN
    v_comm_type := prod.commission_type;
    DECLARE
      base_amount NUMERIC;
    BEGIN
      -- Basis für Provision
      IF prod.commission_base = 'service_fee' THEN
        base_amount := v_service_fee;
      ELSIF prod.commission_base = 'total' THEN
        base_amount := p_sale_amount + v_service_fee;
      ELSE
        base_amount := p_sale_amount; -- sale_amount (default)
      END IF;

      -- Provision nach Typ
      IF prod.commission_type = 'fixed' THEN
        v_commission := prod.commission_value;
      ELSIF prod.commission_type = 'percentage' THEN
        v_commission := ROUND(base_amount * prod.commission_value / 100, 2);
      ELSIF prod.commission_type = 'points' THEN
        v_points := prod.commission_points;
        v_commission := 0;
      ELSIF prod.commission_type = 'hybrid' THEN
        v_commission := ROUND(base_amount * prod.commission_value / 100, 2);
        v_points := prod.commission_points;
      END IF;
    END;
  END IF;

  -- Händler-Erlös
  RETURN QUERY SELECT
    v_service_fee,
    v_platform_fee,
    v_commission,
    v_points,
    ROUND(p_sale_amount + v_service_fee - v_platform_fee - v_commission, 2),
    v_comm_type;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 14. SOSUA PESCE – Erste Händler-Instanz
-- ============================================================

-- Händler anlegen
INSERT INTO merchants (
  slug, name, description, category,
  whatsapp_number, email, phone,
  currency, language,
  stripe_link,
  platform_fee_type, platform_fee_value, base_fee,
  admin_password
) VALUES (
  'sosuapesce',
  'Sosua Pesce',
  'Pescado fresco directo a tu puerta en Sosua, RD',
  'fish',
  '18299758857',
  'office@ynhald.com',
  '+18299758857',
  'RD$', 'es',
  'https://buy.stripe.com/bJedRa0hL3kOg76fIy3Ru04',
  'fixed', 50, 0,
  'Austria714#'
) ON CONFLICT (slug) DO NOTHING;

-- Produkt anlegen
INSERT INTO merchant_products (
  merchant_id, name, description,
  price_type, price, currency,
  service_fee_type, service_fee,
  payment_method,
  fulfillment_type,
  commission_type, commission_value, commission_base,
  is_featured, status
)
SELECT
  id,
  'Entrega de Pescado Fresco',
  'Coordinacion de entrega de pescado fresco directo del mar a tu puerta en Sosua',
  'negotiated', 0, 'RD$',
  'fixed', 500,
  'hybrid',
  'delivery',
  'fixed', 150, 'service_fee',
  true, 'active'
FROM merchants WHERE slug = 'sosuapesce'
ON CONFLICT DO NOTHING;

-- Provisionsregeln anlegen
INSERT INTO merchant_commission_rules (
  merchant_id,
  min_new_customers_per_month,
  pause_commission_action,
  freeze_after_months,
  min_payout_amount,
  payout_schedule,
  new_customer_definition
)
SELECT
  id, 1, 'accumulate', 3, 1000, 'bimonthly', 'never_bought'
FROM merchants WHERE slug = 'sosuapesce'
ON CONFLICT DO NOTHING;

-- ============================================================
-- 15. VIEWS für Berichte
-- ============================================================

-- Agent-Kontostand pro Händler
CREATE OR REPLACE VIEW agent_balances AS
SELECT
  a.id AS agent_id,
  a.name AS agent_name,
  a.email,
  a.phone,
  m.slug AS merchant_slug,
  m.name AS merchant_name,
  m.currency,
  aml.id AS link_id,
  aml.ref_code,
  aml.status,
  aml.new_customers_count,
  aml.total_sales_count,
  aml.total_earned,
  aml.total_paid,
  aml.accumulated_amount,
  aml.points_balance,
  aml.consecutive_pauses,
  aml.last_new_customer_at,
  COALESCE(aml.total_earned - aml.total_paid, 0) AS balance_due
FROM agents a
JOIN agent_merchant_links aml ON aml.agent_id = a.id
JOIN merchants m ON m.id = aml.merchant_id;

-- Abrechnungsbericht
CREATE OR REPLACE VIEW billing_report AS
SELECT
  m.slug AS merchant_slug,
  m.name AS merchant_name,
  m.currency,
  a.name AS agent_name,
  a.email AS agent_email,
  a.phone AS agent_phone,
  aml.ref_code,
  aml.status AS agent_status,
  COUNT(s.id) AS deliveries,
  COALESCE(SUM(s.commission_amount), 0) AS commission_earned,
  COALESCE(aml.total_paid, 0) AS already_paid,
  COALESCE(aml.total_earned - aml.total_paid, 0) AS balance_due,
  aml.accumulated_amount AS accumulated_during_pause,
  aml.points_balance
FROM agent_merchant_links aml
JOIN agents a ON a.id = aml.agent_id
JOIN merchants m ON m.id = aml.merchant_id
LEFT JOIN sales s ON s.agent_id = a.id AND s.merchant_id = m.id AND s.status = 'delivered'
GROUP BY m.slug, m.name, m.currency, a.name, a.email, a.phone,
         aml.ref_code, aml.status, aml.total_paid, aml.total_earned,
         aml.accumulated_amount, aml.points_balance;

-- Plattform-Übersicht
CREATE OR REPLACE VIEW platform_overview AS
SELECT
  m.slug, m.name, m.status,
  COUNT(DISTINCT aml.agent_id) FILTER (WHERE aml.status = 'active') AS active_agents,
  COUNT(DISTINCT aml.agent_id) FILTER (WHERE aml.status = 'paused') AS paused_agents,
  COUNT(DISTINCT s.id) AS total_sales,
  COALESCE(SUM(s.sale_amount), 0) AS total_revenue,
  COALESCE(SUM(s.platform_fee), 0) AS platform_earnings,
  COALESCE(SUM(s.commission_amount), 0) AS total_commissions
FROM merchants m
LEFT JOIN agent_merchant_links aml ON aml.merchant_id = m.id
LEFT JOIN sales s ON s.merchant_id = m.id AND s.status = 'delivered'
GROUP BY m.slug, m.name, m.status;

