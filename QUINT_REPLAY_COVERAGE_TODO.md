# Quint replay coverage TODO

Follow-up coverage gaps from the October 2026 audit. The existing
[Accumulate TODO](QUINT_REPLAY_TODO.md) records earlier completed work.
Items 5 and 6 are the first implementation priorities. These are replay coverage
limits; separate Rust tests cover some excluded cases.

## 1 Authorization pipeline

- [ ] TODO: Execute IsAuthorized before Refine and Accumulate, including invalid
  signatures, malformed configuration/token/trace bytes, and package counts.

## 2 Refine executable and byte domains

- [ ] TODO: Cover invalid PVF binaries, malformed candidate payloads, arbitrary
  executable behavior, and Refine gas exhaustion with independent expectations.
  The current interpreter PVF executes generated host-call scripts.

## 3 Historical lookup lifecycle

- [ ] TODO: Exercise actual historical availability across provision, forgetting,
  code upgrades, and lookup anchors instead of an isolated availability input.

## 4 Successful supervision operations

- [ ] TODO: Add mutable supervision and supervisor balances to the host, then
  replay successful foreign preimage operations, storage removal, handoffs,
  ejection, supervised transfers, and incoming balance selectors.

## 5 Individual host calls

- [ ] TODO: Compare successful assignment arguments and order, including repeated
  writes to one core and independent cores, with checkpoint-aware rollback.
- [ ] TODO: Retain and compare every successful designation and service upgrade,
  including intermediate calls overwritten before the invocation returns.
- [ ] TODO: Preserve final assignment-effect comparisons and add mutations that leave final
  effects unchanged while corrupting the intermediate call history. The host
  observation is gated by PolkaJAM's `hazmat` feature.

## 6 Storage failures and recovery combinations

- [ ] TODO: Add `storage_recovery`: head, KV, incoming queue, registration/forced-head
  metadata, and staging failures with exhaustion before, inside, and after report
  checkpoints. Check retained prefixes, incoming credits, free balance, and retries.
- [ ] TODO: Extend this recovery profile to compact-encoded balance growth,
  forced-code acquisition/metadata, and code-announcement storage failures.
- [ ] TODO: Cover nonempty validator finalization under constrained host balance.
- [ ] TODO: Model low-balance failure at remaining upward-message write sites and
  mix those failures with gas recovery; never infer the oracle from Rust effects.
- [ ] TODO: Require every recovery phase, head and metadata failures during interrupted
  invocations, and later successful invocations in generated coverage assertions.

## 7 Upgrade migrations and transfer delivery

- [ ] TODO: Upgrade between genuinely different implementations/storage layouts.
- [ ] TODO: Execute destination Accumulate after deferred delivery, including
  self-transfer queue entries, rather than only crediting destination balances.

## 8 Larger generated domains

- [ ] TODO: Generate larger sustained batches and arbitrary byte distributions;
  keep dedicated exact-boundary fixtures and collision-free model mappings.
- [ ] TODO: Make focused Refine boundary generation available to continuous
  campaigns, with assertions for required outcomes.
