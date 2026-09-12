// Envelope helpers over the wire format:
//   { "state": <json or null>, "effects": [ { "type": "...", ... } ] }

///|
/// A decoded bridge envelope. `state` is None when the wire carried an
/// explicit JSON null (the not-initialized error path); an envelope
/// without a state key is not this protocol and fails to parse.
pub(all) struct Envelope {
  state : Json?
  effects : Array[Json]
} derive(Eq, Debug)

///|
/// Parse a bridge response string into an Envelope. Returns None when the
/// text is not valid JSON or not the envelope shape (state key required,
/// effects must be an array).
pub fn parse_envelope(text : String) -> Envelope? {
  let json : Json = @json.parse(text) catch { _ => return None }
  match json {
    Object(map) =>
      match (map.get("state"), map.get("effects")) {
        (Some(Null), Some(Array(effects))) =>
          Some({ state: None, effects: effects.copy(), })
        (Some(state), Some(Array(effects))) =>
          Some({ state: Some(state), effects: effects.copy(), })
        _ => None
      }
    _ => None
  }
}

///|
/// The effect type tags of an effects array, in wire order.
pub fn effect_types(effects : Array[Json]) -> Array[String] {
  let out : Array[String] = []
  for effect in effects {
    if effect is Object({ "type": String(tag), .. }) {
      out.push(tag)
    }
  }
  out
}

///|
/// Find the first effect with the given type tag; None if absent.
pub fn find_effect(effects : Array[Json], tag : String) -> Json? {
  for effect in effects {
    if effect is Object({ "type": String(t), .. }) {
      if t == tag {
        return Some(effect)
      }
    }
  }
  None
}
