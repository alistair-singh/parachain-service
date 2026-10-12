use super::aura::{self, AuthConfig, AuthToken, SignatureVerifier};
use codec::{DecodeAll, Encode};
use jam_pvm_common::is_authorized::{auth_token, refine_context, work_package};
use jam_types::{AuthTrace, CoreIndex, Slot, WorkPackage};
use parachain_service_core::authorization::AuthTrace as AuraAuthTrace;

#[derive(Debug)]
pub(crate) enum AuthorizationError {
	UndecodableAuthConfig,
	UndecodableAuthToken,
	/// Number of work items does not match the number of para IDs.
	InvalidWorkItemCount,
	/// A work item does not target the Parachain Service.
	InvalidWorkItemService,
	BadAuthorization(aura::AuthorizationError),
}

pub(crate) fn is_authorized<S: SignatureVerifier>(
	_core: CoreIndex,
) -> Result<AuthTrace, AuthorizationError> {
	let package = work_package();
	assert!(
		package.items.len() > 0,
		"work packages need to have at least one item (see Gray Paper)"
	);

	let config = AuthConfig::decode_all(&mut &package.authorizer.config[..])
		.map_err(|_| AuthorizationError::UndecodableAuthConfig)?;
	let token = AuthToken::decode_all(&mut &auth_token().0[..])
		.map_err(|_| AuthorizationError::UndecodableAuthToken)?;

	// §7.1 selects the collator using the recent anchor's timeslot.
	let slot = refine_context().anchor_slot;

	Ok(AuthTrace(authorize::<S>(&config, &token, &package, slot)?.encode()))
}

/// Validate a package without host calls, using the supplied config, token, and slot.
fn authorize<S: SignatureVerifier>(
	config: &AuthConfig,
	token: &AuthToken,
	package: &WorkPackage,
	anchor_slot: Slot,
) -> Result<AuraAuthTrace, AuthorizationError> {
	if package.items.iter().any(|item| item.service != config.parachain_service) {
		return Err(AuthorizationError::InvalidWorkItemService);
	}

	if config.para_ids.len() != package.items.len() {
		return Err(AuthorizationError::InvalidWorkItemCount);
	}
	aura::authorize::<S>(config, token, package, anchor_slot)
		.map_err(AuthorizationError::BadAuthorization)
}

#[cfg(test)]
mod tests;
