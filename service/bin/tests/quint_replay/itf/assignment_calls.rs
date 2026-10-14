//! Successful host assignments, preserving calls hidden by final mutations.
//! The hazmat host emits only completed effects and completed checkpoints.
use std::cell::RefCell;

use jam_codec::Encode;
use serde_json::Value;

use super::{assignments, replay::*};

#[derive(Default)]
struct History {
	calls: Vec<String>,
	checkpoint: usize,
}
thread_local! {
	static HISTORY: RefCell<Option<History>> = const { RefCell::new(None) };
}

pub fn enabled() -> bool {
	HISTORY.with(|history| history.borrow().is_some())
}

pub fn record(event: &str) {
	HISTORY.with(|history| {
		if let Some(history) = history.borrow_mut().as_mut() {
			if event == "checkpoint" {
				history.checkpoint = history.calls.len();
			} else if event.starts_with("assign ") {
				history.calls.push(event.to_owned());
			}
		}
	});
}

pub struct Capture;
impl Capture {
	pub fn start() -> Result<Self, String> {
		super::instruction_gas::observe()?;
		HISTORY.with(|history| {
			let mut history = history.borrow_mut();
			if history.is_some() {
				return Err("nested assignment observation".into());
			}
			*history = Some(History::default());
			Ok(Self)
		})
	}

	pub fn compare(&self, frame: &Value, rollback: bool) -> Result<(), String> {
		let expected = field(frame, "lastStepAssigns")?
			.as_array()
			.ok_or("lastStepAssigns must be a list")?
			.iter()
			.map(|call| {
				let core = bounded_integer::<u16>(field(call, "core")?, "assignment core")?;
				let owner = assignments::service_id(field(call, "assigner")?)?;
				let queue = assignments::queue(field(call, "queue")?)?;
				// AuthQueue has fixed length and no vector prefix in JAM encoding.
				let bytes: Vec<u8> = queue.iter().flat_map(Encode::encode).collect();
				Ok(format!("assign {core} {owner} {bytes:?}"))
			})
			.collect::<Result<Vec<_>, String>>()?;
		HISTORY.with(|history| {
			let history = history.borrow();
			let history = history.as_ref().ok_or("missing assignment observation")?;
			let retained = if rollback { history.checkpoint } else { history.calls.len() };
			if history.calls[..retained] != expected {
				return Err(format!(
					"ordered assignment calls differ: expected {} calls, observed {retained}",
					expected.len()
				));
			}
			Ok(())
		})
	}
}
impl Drop for Capture {
	fn drop(&mut self) {
		HISTORY.with(|history| *history.borrow_mut() = None);
	}
}

#[cfg(test)]
mod tests {
	use super::*;
	use serde_json::json;

	#[test]
	fn checkpoint_history_works() {
		let capture = Capture::start().unwrap();
		record("checkpoint");
		record("assign 1 0 []");
		let empty = json!({"lastStepAssigns": []});
		capture.compare(&empty, true).unwrap();
		assert!(capture.compare(&empty, false).is_err());
		record("checkpoint");
		assert!(capture.compare(&empty, true).is_err());
	}
}
