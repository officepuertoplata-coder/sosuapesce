// ============================================================
// SOSUA PESCE – Configuration
// Fill in your values after creating your Supabase project
// ============================================================

const SP_CONFIG = {

  // ── SUPABASE ──────────────────────────────────────────────
  // Get these from: supabase.com → your project → Settings → API
  SUPABASE_URL:  'https://oxybanupdrfopjionekk.supabase.co',   // ← paste your URL
  SUPABASE_ANON: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im94eWJhbnVwZHJmb3BqaW9uZWtrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcwNTg1MjMsImV4cCI6MjA5MjYzNDUyM30.vmssHhb5u2myX29SAPb496kOfYIEBmnus5ylpe-Z7Uc',     // ← paste anon/public key
  SUPABASE_SERVICE_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im94eWJhbnVwZHJmb3BqaW9uZWtrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NzA1ODUyMywiZXhwIjoyMDkyNjM0NTIzfQ.AqbI5tqSLcAGH0SzqPbYPds3GmiQYerXJ17H74ismz4',   // ← paste service_role key (admin only)

  // ── BUSINESS ──────────────────────────────────────────────
  WA_NUMBER:     '18299758857',
  STRIPE_LINK:   'https://buy.stripe.com/bJedRa0hL3kOg76fIy3Ru04',
  SERVICE_FEE:   500,    // RD$ coordination fee
  COMMISSION:    150,    // RD$ per delivery to agent
  MIN_PAYOUT:    1000,   // RD$ minimum to trigger payout

  // ── ADMIN ─────────────────────────────────────────────────
  // Change this password! Store it safely.
  ADMIN_PASSWORD: 'Austria714#',

  // ── SITE ──────────────────────────────────────────────────
  SITE_URL: 'https://officepuertoplata-coder.github.io/sosuapesce',  // ← your GitHub Pages URL
};
