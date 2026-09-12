// Demo app: a counter over the bridge. Self-test target for the toolkit:
//   node scripts/self-e2e.mjs   drives the built wasm from Node
//   node scripts/self-headless.cjs   drives demo/index.html in a browser

///|
pub(all) struct DemoState {
  count : Int
} derive(Eq, Debug, ToJson)

///|
pub enum DemoEvent {
  Inc
  Dec
  Reset
} derive(Eq, Debug)

///|
pub enum DemoEffect {
  Saved
  Notified(message~ : String)
} derive(Eq, Debug)

///|
impl ToJson for DemoEffect with fn to_json(self) {
  match self {
    Saved => { "type": "save" }
    Notified(message~) => { "type": "notify_error", "message": message }
  }
}

///|
impl FromJson for DemoEvent with fn from_json(
  json : Json,
  path : @json.JsonPath,
) -> DemoEvent raise @json.JsonDecodeError {
  match json {
    { "type": "inc", .. } => Inc
    { "type": "dec", .. } => Dec
    { "type": "reset", .. } => Reset
    _ => raise @json.JsonDecodeError((path, "unknown event"))
  }
}

///|
impl FromJson for DemoState with fn from_json(
  json : Json,
  path : @json.JsonPath,
) -> DemoState raise @json.JsonDecodeError {
  match json {
    { "count": Number(n, ..), .. } => { count: n.to_int(), }
    _ => raise @json.JsonDecodeError((path, "expected {\"count\": number}"))
  }
}

///|
fn update(state : DemoState, ev : DemoEvent) -> (DemoState, Array[DemoEffect]) {
  match ev {
    Inc => ({ count: state.count + 1, }, [Saved])
    Dec if state.count > 0 => ({ count: state.count - 1, }, [Saved])
    Dec => (state, [Notified(message="已经是 0 了")])
    Reset => ({ count: 0, }, [Saved])
  }
}

///|
let session : @bridge.Session[DemoState, DemoEvent, DemoEffect] = @bridge.Session::make(
  update,
)

///|
#export_name("demo_init")
pub fn demo_init(stored : String) -> String {
  let initial : DemoState = if stored == "" {
    { count: 0, }
  } else {
    @json.from_json(@json.parse(stored)) catch {
      _ => { count: 0, }
    }
  }
  session.init(initial, [])
}

///|
#export_name("demo_dispatch")
pub fn demo_dispatch(event : String) -> String {
  session.dispatch(event)
}
