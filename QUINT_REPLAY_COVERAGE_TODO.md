# Quint replay coverage TODO

Remaining Rust–Quint replay gaps from the October 2026 audit. Completed work is
removed from this list; current coverage is documented in
[the fixture guide](service/bin/tests/fixtures/quint/README.md).
These are replay coverage limits; separate Rust tests cover some excluded cases.

Prioritize inline assignment recovery, the authorization pipeline, then Refine
malformed-byte, executable, and gas coverage.

## 1 Accumulate storage failures and recovery

- [ ] TODO: Extend assignment storage recovery to inline assignments and their
  post-call cache/index writes; include a later due flush after rejected writes.
- [ ] TODO: Audit remaining upward-message write-site boundaries (including KV
  charge-record growth) and combine failures with gas recovery; never infer the
  oracle from Rust effects.

## 2 Authorization pipeline

- [ ] TODO: Execute IsAuthorized before Refine and Accumulate, including invalid
  signatures and malformed configuration/token/trace bytes.

## 3 Refine executable, byte, and package domains

- [ ] TODO: Cover malformed candidate payloads and invalid PVF binaries. Replay
  currently constructs valid candidate encodings and runs a scripted interpreter PVF.
- [ ] TODO: Cover arbitrary PVF execution and Refine gas exhaustion with
  independent expectations.
- [ ] TODO: Extend package inputs beyond the adapter's one-or-two-item domain
  and identical code references, including invalid item counts and heterogeneous
  references. Resolve model-to-Rust error representation gaps explicitly.

## 4 Refine historical lookup lifecycle

- [ ] TODO: Exercise actual historical availability across provision, forgetting,
  code upgrades, and lookup anchors instead of an isolated availability input.

## 5 Accumulate upgrade migrations and transfer delivery

- [ ] TODO: Upgrade between different implementations/storage layouts; both
  replay upgrade blobs currently execute the same implementation.
- [ ] TODO: Execute destination Accumulate after deferred delivery, including
  self-transfer queue entries, rather than only crediting destination balances.

## 6 Successful supervision operations — requires host support

- [ ] TODO: Add mutable supervision to the host, then replay successful foreign
  preimage operations, storage removal, supervisor handoffs, and ejection.
- [ ] TODO: Add supervisor balances and replay successful supervised transfers
  and incoming destination-balance selectors. Keep unsupported traces explicitly
  rejected until the host supports them.

## 7 Generated domains and combined coverage

- [ ] TODO: Generate larger sustained batches and arbitrary byte distributions;
  keep dedicated exact-boundary fixtures and collision-free model mappings.
- [ ] TODO: Make focused Refine boundary generation available to continuous
  campaigns, with assertions for required outcomes.
- [ ] TODO: Extend combined Refine → Accumulate campaigns to the dedicated
  storage-failure/recovery scenarios that currently inject work results directly.
- [ ] TODO: Broaden sampled Accumulate gas cutoffs and combinations with report
  rejection and natural traps. Current sampling is not exhaustive across every
  instruction; preserve independent checkpoint expectations.
