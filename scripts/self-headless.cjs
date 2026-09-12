// Self headless (task 1.6, local-only — needs a Chromium-family browser):
// the headless runner drives demo/index.html and extracts its in-page
// self-check results via the marker contract. Run after
// `moon build --target wasm-gc --release`:
//   node scripts/self-headless.cjs
const path = require('node:path');
const fs = require('node:fs');
const os = require('node:os');
const {
  serveStatic,
  runChromium,
  extractHarnessSummary,
  report,
} = require('../node/headless.cjs');

const ROOT = path.join(__dirname, '..');
const WASM_SRC = path.join(
  ROOT,
  '_build',
  'wasm-gc',
  'release',
  'build',
  'demoapp',
  'demoapp.wasm',
);
const WASM_DST = path.join(ROOT, 'demo', 'wasm', 'demoapp.wasm');

(async () => {
  if (!fs.existsSync(WASM_SRC)) {
    console.error('missing build output; run: moon build --target wasm-gc --release');
    process.exit(1);
  }
  fs.mkdirSync(path.dirname(WASM_DST), { recursive: true });
  fs.copyFileSync(WASM_SRC, WASM_DST);

  const profileRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'moonwebtest-'));
  const site = await serveStatic(ROOT, 8933);
  let failed = 0;

  const dom = await runChromium({
    args: ['--dump-dom', site.url + 'demo/index.html'],
    profileRoot,
    waitMarker: 'test-summary',
  });
  const sum = extractHarnessSummary(dom);
  for (const line of sum.failLines) {
    console.log('  ' + line);
  }
  console.log(`  demo page: ${sum.passed} passed, ${sum.failed} failed :: ${sum.summaryText}`);
  failed += report('demo page harness summary', sum.ok);

  // screenshot for a human once-over
  const shot = path.join(ROOT, 'demo-screenshot.png');
  await runChromium({
    args: [`--screenshot=${shot}`, site.url + 'demo/index.html'],
    profileRoot,
    waitMarker: 'test-summary',
  });
  console.log('screenshot:', shot);

  await site.close();
  fs.rmSync(profileRoot, { recursive: true, force: true });
  console.log(failed === 0 ? 'SELF-HEADLESS CHECKS PASSED' : failed + ' FAILURES');
  process.exit(failed === 0 ? 0 : 1);
})();
