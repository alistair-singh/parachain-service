//! Refine output of the parachain service.

use codec::{Decode, Encode};
use jam_types::Hash;
use parachain_service_core::upward_message::UpwardMessages;

// Shared wire types live in the interface crate; re-exported here since they are
// part of the digest's shape.
pub use parachain_service_core::log::{RefineLog, MAX_REPORT_ERROR_PAYLOAD};
pub use parachain_service_core::types::{
	HeadData, ParaId, Timeslot, ValidationCodeHash, ValidationCodeRef,
};

#[cfg(feature = "std")]
use jam_std_common::hash_raw;

/// Maximum combined encoded size of all `ParachainWorkDigest`s and the auth
/// trace — the Gray Paper's `W_R` (`C_maxreportvarsize`).
pub const MAX_REFINE_OUTPUT_SIZE: usize = 48 * 1024;

/// The parachain service's Refine output for one parachain candidate. Side
/// effects from host functions are carried in `upward_messages` and applied by
/// Accumulate. Spec §3.3.
#[derive(Clone, Debug, PartialEq, Eq, Encode, Decode)]
pub enum ParachainWorkDigest {
	/// PVF validation succeeded.
	Ok {
		/// The parachain this digest belongs to.
		para_id: ParaId,
		/// Hash of the validation code Refine used to check the candidate.
		validation_code: ValidationCodeHash,
		/// Hash of the parent head data this candidate was built on top of.
		parent_head_hash: Hash,
		/// New head data produced by the parachain block.
		head_data: HeadData,
		/// Upward messages emitted through host functions during Refine.
		upward_messages: UpwardMessages,
		/// The work package's lookup-anchor timeslot.
		lookup_anchor: Timeslot,
	},
	/// Refine failed. See §4.1.
	Err {
		/// The parachain this failure belongs to.
		para_id: ParaId,
		/// Hash of the validation code the candidate names. See §5.1 step 2.
		validation_code: ValidationCodeHash,
		/// Structured failure reason.
		error: RefineLog,
	},
}

impl ParachainWorkDigest {
	pub fn para_id(&self) -> ParaId {
		match self {
			Self::Ok { para_id, .. } => *para_id,
			Self::Err { para_id, .. } => *para_id,
		}
	}

	pub fn validation_code(&self) -> ValidationCodeHash {
		match self {
			Self::Ok { validation_code, .. } => *validation_code,
			Self::Err { validation_code, .. } => *validation_code,
		}
	}
}

#[cfg(feature = "test-utils")]
impl ParachainWorkDigest {
	pub fn try_into_log(self) -> Result<RefineLog, ()> {
		match self {
			Self::Ok { .. } => Err(()),
			Self::Err { error, .. } => Ok(error),
		}
	}
}

/// Hash a validation-code blob into its [`ValidationCodeHash`].
#[cfg(feature = "std")]
pub fn validation_code_hash(code: &[u8]) -> ValidationCodeHash {
	ValidationCodeHash::from(hash_raw(code))
}
