// Documentation screenshot capture for the veterinary dashboard.
// Full-page (scrollable) captures of every route, using system Chrome via
// Playwright — no browser download.
//
//   1. npm run dev            (in apps/dashboard, leave running)
//   2. node scripts/screenshots.mjs
//
// Output: docs/screenshots/dashboard/*.png
// Logs in with the seeded vet account against whatever VITE_SUPABASE_URL points
// at, so the pages render with real data.
import { chromium } from 'playwright';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.resolve(__dirname, '../../../docs/screenshots/dashboard');
const BASE = process.env.BASE_URL ?? 'http://localhost:5173';
const EMAIL = process.env.VET_EMAIL ?? 'vet@example.com';
const PASSWORD = process.env.VET_PASSWORD ?? 'password123';

const browser = await chromium.launch({ channel: 'chrome', headless: true });
const page = await browser.newPage({
  viewport: { width: 1440, height: 900 },
  deviceScaleFactor: 2,
});

async function shot(name) {
  await page.waitForLoadState('networkidle').catch(() => {});
  await page.waitForTimeout(900); // let charts finish their entrance
  await page.screenshot({ path: path.join(OUT, `${name}.png`), fullPage: true });
  console.log('  ✓', name);
}

// Login screen (unauthenticated).
await page.goto(`${BASE}/login`, { waitUntil: 'domcontentloaded' });
await shot('login');

// Authenticate.
await page.fill('#login-email', EMAIL);
await page.fill('#login-password', PASSWORD);
await page.click('button[type=submit]');
await page.waitForURL((u) => !u.pathname.startsWith('/login'), { timeout: 20000 });
await page.waitForLoadState('networkidle').catch(() => {});

// Board first, so we can read a real dog id from a card link.
await page.goto(`${BASE}/board`, { waitUntil: 'domcontentloaded' });
await shot('board');

const href = await page
  .locator('a[href^="/dogs/"]')
  .first()
  .getAttribute('href')
  .catch(() => null);
const dogId = href ? href.split('/dogs/')[1].split('/')[0] : null;
if (!dogId) console.warn('  ! no dog link found — skipping dog detail/review');

const routes = [
  ['alerts', '/alerts'],
  ['reports', '/reports'],
  ['handover', '/handover'],
  ['devices', '/devices'],
  ['admin', '/admin/users'],
  ...(dogId
    ? [
        ['dog_detail', `/dogs/${dogId}`],
        ['vet_review', `/dogs/${dogId}/review`],
      ]
    : []),
];

for (const [name, route] of routes) {
  await page.goto(`${BASE}${route}`, { waitUntil: 'domcontentloaded' });
  await shot(name);
}

await browser.close();
console.log('done →', OUT);
