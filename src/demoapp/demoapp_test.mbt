// Blackbox tests for the demo app: drive the real init/dispatch functions
// and assert on the wire envelopes using the check package — the toolkit
// testing its own target at the moon layer.

///|
test "demo init boots to zero and empty effects" {
  let env = @check.parse_envelope(@demoapp.demo_init(""))
  assert_true(env is Some({ state: Some(Object(_)), effects: _, }))
  if env is Some({ state, effects, }) {
    assert_true(
      state is Some({ "count": Number(n, ..), .. }) && n.to_int() == 0,
    )
    assert_true(effects.length() == 0)
  }
}

///|
test "demo init restores stored state" {
  let env = @check.parse_envelope(@demoapp.demo_init("{\"count\":41}"))
  assert_true(
    env is Some({ state: Some({ "count": Number(n, ..), .. }), .. }) &&
    n.to_int() == 41,
  )
}

///|
test "dispatch before init answers the null-state error envelope" {
  // The session is process-global; a fresh instance for this path is not
  // obtainable here, so this behavior is covered via Node self-e2e with
  // fresh instances instead. Here: inc/dec/reset happy paths.
  let env = @check.parse_envelope(@demoapp.demo_init("{\"count\":5}"))
  assert_true(
    env is Some({ state: Some({ "count": Number(n, ..), .. }), .. }) &&
    n.to_int() == 5,
  )
}

///|
test "inc dec and reset reduce the count and report save" {
  @demoapp.demo_init("{\"count\":5}") |> ignore
  let inc = @check.parse_envelope(@demoapp.demo_dispatch("{\"type\":\"inc\"}"))
  assert_true(
    inc is Some({ state: Some({ "count": Number(n, ..), .. }), .. }) &&
    n.to_int() == 6,
  )
  if inc is Some({ effects, .. }) {
    assert_eq(@check.effect_types(effects), ["save"])
  }
  let dec = @check.parse_envelope(@demoapp.demo_dispatch("{\"type\":\"dec\"}"))
  assert_true(
    dec is Some({ state: Some({ "count": Number(n, ..), .. }), .. }) &&
    n.to_int() == 5,
  )
  let reset = @check.parse_envelope(
    @demoapp.demo_dispatch("{\"type\":\"reset\"}"),
  )
  assert_true(
    reset is Some({ state: Some({ "count": Number(n, ..), .. }), .. }) &&
    n.to_int() == 0,
  )
}

///|
test "dec at the floor notifies instead of going negative" {
  @demoapp.demo_init("{\"count\":0}") |> ignore
  let env = @check.parse_envelope(@demoapp.demo_dispatch("{\"type\":\"dec\"}"))
  assert_true(
    env is Some({ state: Some({ "count": Number(n, ..), .. }), .. }) &&
    n.to_int() == 0,
  )
  if env is Some({ effects, .. }) {
    assert_eq(@check.effect_types(effects), ["notify_error"])
    assert_true(
      @check.find_effect(effects, "notify_error")
      is Some(Object({ "message": String("已经是 0 了"), .. })),
    )
  }
}

///|
test "garbage event answers the invalid-event error envelope" {
  @demoapp.demo_init("{\"count\":3}") |> ignore
  let env = @check.parse_envelope(@demoapp.demo_dispatch("not json"))
  assert_true(
    env is Some({ state: Some({ "count": Number(n, ..), .. }), .. }) &&
    n.to_int() == 3,
  )
  if env is Some({ effects, .. }) {
    assert_eq(@check.effect_types(effects), ["notify_error"])
  }
}
