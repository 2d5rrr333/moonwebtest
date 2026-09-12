// Blackbox tests for the check package: envelope parsing and effect
// assertions over the documented wire shapes.

///|
test "parse: valid envelope with state and effects" {
  let env = @check.parse_envelope(
    "{\"state\":{\"count\":3},\"effects\":[{\"type\":\"save\"},{\"type\":\"notify_error\",\"message\":\"x\"}]}",
  )
  assert_true(env is Some({ state: Some(Object(_)), effects: _, }))
  if env is Some({ effects, .. }) {
    assert_eq(@check.effect_types(effects), ["save", "notify_error"])
    assert_true(
      @check.find_effect(effects, "notify_error")
      is Some(Object({ "message": String("x"), .. })),
    )
    assert_true(@check.find_effect(effects, "toast") is None)
  }
}

///|
test "parse: null state (uninitialized error path)" {
  let env = @check.parse_envelope(
    "{\"state\":null,\"effects\":[{\"type\":\"notify_error\",\"message\":\"未初始化\"}]}",
  )
  assert_true(env is Some({ state: None, effects: _, }))
  if env is Some({ effects, .. }) {
    assert_eq(@check.effect_types(effects), ["notify_error"])
  }
}

///|
test "parse: empty effects emit an empty array" {
  let env = @check.parse_envelope("{\"state\":1,\"effects\":[]}")
  assert_true(
    env is Some({ state: Some(Number(_, ..)), effects, }) &&
    effects.length() == 0,
  )
}

///|
test "parse: rejects non-envelope shapes" {
  assert_true(@check.parse_envelope("not json") is None)
  assert_true(@check.parse_envelope("[1,2]") is None)
  assert_true(@check.parse_envelope("{\"state\":1}") is None)
  assert_true(@check.parse_envelope("{\"effects\":[]}") is None)
}

///|
test "effect_types skips objects without a string type" {
  let effects : Array[Json] = [{ "type": "save" }, { "message": "no type" }, 42]
  assert_eq(@check.effect_types(effects), ["save"])
}
