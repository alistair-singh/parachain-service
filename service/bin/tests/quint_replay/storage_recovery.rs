//! Storage backstop failures combined with independently selected checkpoints.
use super::itf::replay;
use serde_json::{json, Value};

const FIXTURES: [&str; 3] = [
	include_str!("../fixtures/quint/storage_recovery/queue_recovery_works.itf.json"),
	include_str!("../fixtures/quint/storage_recovery/metadata_recovery_works.itf.json"),
	include_str!("../fixtures/quint/storage_recovery/staging_recovery_works.itf.json"),
];

#[test]
fn sampled_recovery_works() {
	for fixture in FIXTURES {
		for sample in [0, 250000, 500000, 750000, 1000000] {
			let mut trace: Value = serde_json::from_str(fixture).unwrap();
			for state in trace["states"].as_array_mut().unwrap().iter_mut().skip(1) {
				if state["replayInterrupt"] != json!({"#bigint":"-1"}) {
					state["replayGasSample"] = json!({"#bigint":sample.to_string()});
				}
			}
			replay::document_trace(&trace).unwrap();
		}
	}
}

#[test]
fn lost_checkpoint_state_errors() {
	let mut trace: Value = serde_json::from_str(FIXTURES[2]).unwrap();
	trace["states"][3]["svc"]["stagedValidatorKeys"] = json!([]);
	assert!(replay::document_trace(&trace).is_err());
}
