// ============================================================
// SOSUA PESCE – Configuration
// Fill in your values after creating your Supabase project
// ============================================================

const SP_CONFIG = {

  // ── SUPABASE ──────────────────────────────────────────────
  // Get these from: supabase.com → your project → Settings → API
  SUPABASE_URL:  'https://XXXXXXXXXXXX.supabase.co',   // ← paste your URL
  SUPABASE_ANON: 'eyXXXXXXXXXXXXXXXXXXXXXXXXXX',     // ← paste anon/public key
  SUPABASE_SERVICE_KEY: 'eyXXXXXXXXXXXXXXXXXXXXXX',   // ← paste service_role key (admin only)

  // ── BUSINESS ──────────────────────────────────────────────
  WA_NUMBER:     '18299758857',
  STRIPE_LINK:   'https://buy.stripe.com/bJedRa0hL3kOg76fIy3Ru04',
  SERVICE_FEE:   500,    // RD$ coordination fee
  COMMISSION:    150,    // RD$ per delivery to agent
  MIN_PAYOUT:    1000,   // RD$ minimum to trigger payout

  // ── ADMIN ─────────────────────────────────────────────────
  // Change this password! Store it safely.
  ADMIN_PASSWORD: 'sosuapesce2025',

  // ── SITE ──────────────────────────────────────────────────
  SITE_URL: 'https://YOUR-USERNAME.github.io/sosuapesce',  // ← your GitHub Pages URL
};
