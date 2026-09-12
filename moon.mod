// moonwebtest: three-layer test toolkit for MoonBit wasm-gc web apps.

name = "2d5rrr333/moonwebtest"

version = "0.1.0"

readme = "README.md"

repository = "https://github.com/2d5rrr333/moonwebtest"

license = "Apache-2.0"

keywords = [ "testing", "e2e", "headless", "wasm", "bridge" ]

import {
  "2d5rrr333/moonbridge@0.1.0",
}

source = "src"

preferred_target = "wasm-gc"

description = "Test toolkit for MoonBit wasm-gc web apps: a Node harness that drives your wasm exports over the JSON bridge, a headless-Chromium runner for DOM assertions, and moon-level envelope checks. The tools test themselves against the bundled demo app."
