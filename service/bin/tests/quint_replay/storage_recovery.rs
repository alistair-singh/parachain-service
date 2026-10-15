//! Storage backstop failures combined with independently selected checkpoints.
use super::itf::replay;
use serde_json::{json, Value};

const FIXTURES: [&str; 9] = [
	include_str!("../fixtures/quint/storage_recovery/queue_recovery_works.itf.json"),
	include_str!("../fixtures/quint/storage_recovery/metadata_recovery_works.itf.json"),
	include_str!("../fixtures/quint/storage_recovery/staging_recovery_works.itf.json"),
	include_str!("../fixtures/quint/storage_recovery/balance_u30_recovery_works.itf.json"),
	include_str!("../fixtures/quint/storage_recovery/balance_u32_recovery_works.itf.json"),
	include_str!("../fixtures/quint/storage_recovery/balance_u40_recovery_works.itf.json"),
	include_str!("../fixtures/quint/storage_recovery/balance_u48_recovery_works.itf.json"),
	include_str!("../fixtures/quint/storage_recovery/balance_u56_recovery_works.itf.json"),
	include_str!(
		"../fixtures/quint/storage_recovery/validator_finalization_recovery_works.itf.json"
	),
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

#[test]
fn lost_balance_checkpoint_errors() {
	for fixture in &FIXTURES[3..8] {
		let mut trace: Value = serde_json::from_str(fixture).unwrap();
		// Frame six retains the successful one-byte growth at the final checkpoint.
		assert_ne!(trace["states"][6]["svc"], trace["states"][5]["svc"]);
		trace["states"][6]["svc"] = trace["states"][5]["svc"].clone();
		assert!(replay::document_trace(&trace).is_err());
	}
}

#[test]
fn lost_finalization_checkpoint_errors() {
	let original: Value = serde_json::from_str(FIXTURES[8]).unwrap();
	// Rollback retains the staged buffer; the final checkpoint retains designation.
	assert_eq!(original["states"][4]["svc"]["stagedValidatorKeys"].as_array().unwrap().len(), 5);
	assert_eq!(original["states"][5]["replayDesignate"].as_array().unwrap().len(), 6);
	for field in ["replayDesignate", "replayStorageFree"] {
		let mut trace = original.clone();
		trace["states"][5][field] = trace["states"][4][field].clone();
		assert!(replay::document_trace(&trace).is_err(), "{field}");
	}
}
