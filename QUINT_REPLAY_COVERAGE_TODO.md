# Quint replay coverage TODO

Remaining Rust–Quint replay gaps from the October 2026 audit. Completed work is
removed from this list; current coverage is documented in
[the fixture guide](service/bin/tests/fixtures/quint/README.md).
These are replay coverage limits; separate Rust tests cover some excluded cases.

Prioritize the remaining Accumulate write-site audit.

## 1 Accumulate storage failures and recovery

- [ ] TODO: Extend KV charge-record boundary coverage to generated campaigns and
  additional compact widths; the fixed insertion/overwrite fixtures now cover
  charge rejection, KV rollback, retry, shrink/refund, and gas recovery at 2^30.
- [ ] TODO: Combine cleanup/refund and code-apply write sequences with instruction
  gas recovery. Their storage writes shrink or retain their footprints, so host
  deposit rejection is not the missing case; preserve independent checkpoint
  expectations.

## 2 Refine executable, byte, and package domains

- [ ] TODO: Extend invalid PVF coverage beyond empty, bad-magic, and truncated
  binaries to structurally valid containers with invalid memory maps or missing
  entry points; integrate byte faults into Refine → Accumulate campaigns.
- [ ] TODO: Extend beyond zero-entry and infinite-child gas exhaustion to arbitrary
  PVF execution and instruction cutoffs with independent expectations; integrate
  gas faults into Refine → Accumulate campaigns.
- [ ] TODO: Extend package inputs beyond the adapter's one-or-two-item domain
  and identical code references, including invalid item counts and heterogeneous
  references. Resolve model-to-Rust error representation gaps explicitly.

## 3 Refine historical lookup lifecycle

- [ ] TODO: Exercise actual historical availability across provision, forgetting,
  code upgrades, and lookup anchors instead of an isolated availability input.

## 4 Accumulate upgrade migrations and transfer delivery

- [ ] TODO: Upgrade between different implementations/storage layouts; both
  replay upgrade blobs currently execute the same implementation.
- [ ] TODO: Execute destination Accumulate after deferred delivery, including
  self-transfer queue entries, rather than only crediting destination balances.

## 5 Successful supervision operations — requires host support

- [ ] TODO: Add mutable supervision to the host, then replay successful foreign
  preimage operations, storage removal, supervisor handoffs, and ejection.
- [ ] TODO: Add supervisor balances and replay successful supervised transfers
  and incoming destination-balance selectors. Keep unsupported traces explicitly
  rejected until the host supports them.

## 6 Generated domains and combined coverage

- [ ] TODO: Generate larger sustained batches and arbitrary byte distributions;
  keep dedicated exact-boundary fixtures and collision-free model mappings.
- [ ] TODO: Make focused Refine boundary generation available to continuous
  campaigns, with assertions for required outcomes.
- [ ] TODO: Extend combined Refine → Accumulate campaigns to the dedicated
  storage-failure/recovery scenarios that currently inject work results directly.
- [ ] TODO: Broaden sampled Accumulate gas cutoffs and combinations with report
  rejection and natural traps. Current sampling is not exhaustive across every
  instruction; preserve independent checkpoint expectations. Include due-flush
  exhaustion: current sampling removes its initial gas allowance, so recovery
  fixtures exercise later due flushes only in fully funded invocations.
- [ ] TODO: Extend the authorization replay beyond its fixed single-collator
  tree to collator rotation, deeper Merkle proofs, and authorization gas exhaustion.
