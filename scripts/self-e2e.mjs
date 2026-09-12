// Self e2e (task 1.6): the Node bridge harness drives the demo app's real
// wasm. Run after `moon build --target wasm-gc --release`:
//   node scripts/self-e2e.mjs
import { loadBridge, makeChecks } from '../node/bridge-harness.mjs';

const WASM = new URL(
  '../_build/wasm-gc/release/build/demoapp/demoapp.wasm',
  import.meta.url,
).pathname.replace(/^\/([A-Za-z]:)/, '$1');

const { check, finish } = makeChecks();

// -- init paths --
let app = loadBridge(WASM, { init: 'demo_init', dispatch: 'demo_dispatch' });
let r = app.init('');
check('init default zero', r.state.count === 0 && r.effects.length === 0, r);

const stored = loadBridge(WASM, { init: 'demo_init', dispatch: 'demo_dispatch' });
r = stored.init('{"count":41}');
check('init restores stored state', r.state.count === 41, r);

// -- the uninitialized path needs a fresh instance (moon tests share one
// global session, so this is Node-only coverage) --
{
  const fresh = loadBridge(WASM, { init: 'demo_init', dispatch: 'demo_dispatch' });
  const before = fresh.dispatch({ type: 'inc' });
  check(
    'dispatch before init answers null state + notify_error',
    before.state === null &&
      before.effects.length === 1 &&
      before.effects[0].type === 'notify_error' &&
      before.effects[0].message === '未初始化',
    before,
  );
}

// -- event reduction --
r = app.dispatch({ type: 'inc' });
check('inc rolls forward and saves', r.state.count === 1 && r.effects[0].type === 'save', r);

app.dispatch({ type: 'reset' });
r = app.dispatch({ type: 'dec' });
check('dec at floor notifies', r.state.count === 0 && r.effects[0].message === '已经是 0 了', r);

r = app.dispatchRaw('not json');
check('garbage event echoes state', r.state.count === 0 && r.effects[0].type === 'notify_error', r);

r = app.dispatchRaw('{"type":"nope"}');
check('unknown event echoes state', r.state.count === 0 && r.effects[0].type === 'notify_error', r);

// -- instance isolation: one app's dispatches never leak into another --
const iso = loadBridge(WASM, { init: 'demo_init', dispatch: 'demo_dispatch' });
iso.init('{"count":7}');
iso.dispatch({ type: 'inc' });
check('instances are isolated', app.state.count === 0 && iso.state.count === 8);

process.exit(finish());
