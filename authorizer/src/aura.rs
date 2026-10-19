//! AURA adapter for the service's vendored JAM work-package format.

pub use cumulus_aura_authorizer::{
	build_collator_proof, hash_signing_payload, AuthConfig, AuthToken, AuthTrace,
	AuthorizationError, CollatorKey, CollatorProofError, CollatorSignature, ConfigError, ParaId,
	SignatureVerifier, TokenError, WORK_PACKAGE_SIGN_CTX,
};

/// Hash the service's vendored JAM work-package format without converting it to the
/// older published format. In particular, retain every refinement-context field.
pub fn signable_work_package_hash(package: &jam_types::WorkPackage) -> primitive_types::H256 {
	use jam_types::Encode as JamEncode;
	let payload = JamEncode::encode(&(
		&package.auth_code_host,
		&package.authorizer.code_hash,
		&package.context,
		&package.authorizer.config,
		&package.items,
	));
	hash_signing_payload(&payload)
}

/// Apply shared AURA validation to the service's vendored JAM work-package format.
pub(crate) fn authorize<S: SignatureVerifier>(
	config: &AuthConfig,
	token: &AuthToken,
	package: &jam_types::WorkPackage,
	slot: jam_types::Slot,
) -> Result<AuthTrace, AuthorizationError> {
	// TODO: Use AuthConfig::check_work_items once both crates use the same JAM types.
	if package.items.len() != config.para_ids.len() {
		return Err(AuthorizationError::BadConfig(ConfigError::InvalidWorkItemCount));
	}
	if package.items.iter().any(|item| item.service != config.parachain_service) {
		return Err(AuthorizationError::BadConfig(ConfigError::InvalidWorkItemService));
	}
	let collator_index = config.expected_collator_index(slot);
	token.check_proof(config, collator_index)?;
	token
		.check_signature::<S>(signable_work_package_hash(package))
		.map_err(AuthorizationError::BadToken)?;
	Ok(AuthTrace { author_key: token.key })
}
