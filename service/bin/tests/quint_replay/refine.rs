//! Refine execution, including negative checks on the differential oracle.
use crate::itf::replay;
use serde_json::{json, Value};

const SUCCESS: &str = include_str!("../fixtures/quint/refine_fuzz/success_works.itf.json");

#[test]
fn trivial_works() {
	for fixture in [
		SUCCESS,
		include_str!("../fixtures/quint/refine_fuzz/ordering_works.itf.json"),
		include_str!("../fixtures/quint/refine_fuzz/lookup_works.itf.json"),
	] {
		replay::trace(fixture).expect("real Refine must agree with Quint");
	}
}

#[test]
fn incorrect_digest_errors() {
	let mut trace: Value = serde_json::from_str(SUCCESS).unwrap();
	trace["states"][1]["replayRefineExpected"][0]["value"]["value"]["headData"] =
		json!({"#bigint":"9"});
	assert!(replay::document_trace(&trace).unwrap_err().contains("digest differs"));
}

#[test]
fn incorrect_work_failure_errors() {
	let mut trace: Value = serde_json::from_str(SUCCESS).unwrap();
	trace["states"][1]["replayRefineExpected"][0] = json!({"tag":"WorkErr","value":{"#tup":[]}});
	assert!(replay::document_trace(&trace).unwrap_err().contains("expected WorkErr"));
}

#[test]
fn missing_input_errors() {
	let mut trace: Value = serde_json::from_str(SUCCESS).unwrap();
	trace["states"][1].as_object_mut().unwrap().remove("replayRefine");
	assert!(replay::document_trace(&trace)
		.unwrap_err()
		.contains("missing field replayRefine"));
}
