# moonwebtest · MoonBit wasm Web 应用三层测试工具链

[![CI](https://github.com/2d5rrr333/moonwebtest/actions/workflows/ci.yml/badge.svg)](https://github.com/2d5rrr333/moonwebtest/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

用 MoonBit 写了 wasm-gc Web 应用之后，怎么测？本工具链给出与 [moonbridge](https://github.com/2d5rrr333/moonbridge) 架构配套的三层答案，各层各司其职：

| 层 | 工具 | 运行环境 | 测什么 |
|---|---|---|---|
| **moon 层** | `@moonwebtest/check` | `moon test` | 桥协议 wire format：信封形状、effect 类型断言（`parse_envelope` / `effect_types` / `find_effect`） |
| **Node 层** | `node/bridge-harness.mjs` | Node ≥ 18，无浏览器 | 真实 wasm 实例过 FFI 桥：`loadBridge` 加载、`init/dispatch` 返回解析好的信封、`fresh()` 实例隔离 |
| **浏览器层** | `node/headless.cjs` | 任意 Chromium 系浏览器 | 真实渲染与交互：静态服务、无头启动、dump-DOM 捕获、harness 页结果抽取 |

三层都零 npm 依赖。工具自证：本仓库的 demo 计数器应用（`src/demoapp/`，用 moonbridge 写成）由自己的两层工具测试——`scripts/self-e2e.mjs`（Node 层 8 项）与 `scripts/self-headless.cjs`（浏览器层 6 项）。参考使用者：[mtab](https://github.com/2d5rrr333/mtab)（e2e 62 项 + Edge headless 127/129 断言）。

## moon 层：check 包

在黑盒测试里断言**真正过桥的 JSON**，而不是应用内部结构：

```moonbit
// src/yourapp/main_test.mbt
test "dispatch before init answers the null-state error envelope" {
  let env = @check.parse_envelope(your_dispatch_before_init)
  assert_true(env is Some({ state: None, effects: _ }))
}

test "effects carry the right type tags" {
  if env is Some({ effects, .. }) {
    assert_eq(@check.effect_types(effects), ["save", "notify_error"])
    assert_true(@check.find_effect(effects, "notify_error") is Some(
      Object({ "message": String("未初始化"), .. }),
    ))
  }
}
```

依赖：`import { "2d5rrr333/moonwebtest/check" } for "test"`（只在测试构建引入）。

## Node 层：bridge-harness

```js
// your-e2e.mjs
import { loadBridge, makeChecks } from 'moonwebtest/node/bridge-harness.mjs';
// 拷贝 node/ 到你的项目，或直接引用本仓库路径
const app = loadBridge('web/wasm/main.wasm', {
  init: 'mtab_init',            // 你的导出名
  dispatch: 'mtab_dispatch',
});

let r = app.init('', '2025-01-29');   // 解析好的 {state, effects}
r = app.dispatch({ type: 'search_submit', query: 'moonbit' });  // 对象进
r = app.dispatchRaw('not json');       // 或预序列化字符串进（错误路径）
const fresh = app.fresh();            // 隔离实例：未初始化路径等

const { check, finish } = makeChecks();
check('search builds url', r.effects[0].type === 'open_url', r);
process.exit(finish());               // 汇总行 + 退出码
```

要点：模块只编译一次，`fresh()` 快速起隔离实例；`app.state` 跟踪最后一次信封的 state。

## 浏览器层：headless runner

`node/headless.cjs`（CommonJS，`require` 即用）提供：

- `serveStatic(root, port?)` — 静态文件服务（含 `.mjs`/`.wasm` MIME）
- `detectBrowser()` — 浏览器探测：`MOONWEBTEST_BROWSER` 环境变量 → Windows 常见 Edge/Chrome 路径 → PATH 查找（msedge/chrome/chromium/google-chrome）
- `runChromium({ browser?, args, profileRoot, waitMarker?, timeoutMs? })` — 无头启动；`waitMarker`（如 `'test-summary'`）出现即提前收工，超时强杀，每次运行独立 profile（规避被杀浏览器的目录锁）
- `extractHarnessSummary(dom)` — 解析 harness 页结果
- `report(name, ok)` — mtab 风格报告行

**harness 页标记协议**（你的浏览器测试页需遵循）：每项检查输出含 `PASS ` / `FAIL ` 的行；收尾把总结写进 `id="test-summary"` 元素，成功文案匹配 `/ALL \d+ BROWSER CHECKS PASSED/`。参考实现：本仓库 `demo/index.html`、mtab 的 `web/test-harness.html`。

```js
const { serveStatic, runChromium, extractHarnessSummary, report } = require('./node/headless.cjs');
const site = await serveStatic('web', 8932);
const dom = await runChromium({ args: ['--dump-dom', site.url + 'test-harness.html'],
                                profileRoot, waitMarker: 'test-summary' });
const sum = extractHarnessSummary(dom);
failed += report('browser harness', sum.ok);
```

浏览器层需要本机有 Chromium 系浏览器（CI 无浏览器时建议只跑 moon + Node 两层；本仓库 CI 即如此，`self-headless.cjs` 标注 local-only）。

## 自测（工具测工具）

```bash
moon test                                  # check 包 + demoapp 的 moon 层
moon build --target wasm-gc --release      # 构建 demo wasm
node scripts/self-e2e.mjs                  # Node 层：harness 驱动 demoapp
node scripts/self-headless.cjs             # 浏览器层（local-only）
```

## License

Apache-2.0
