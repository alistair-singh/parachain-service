// Independent storage oracle evaluated only through the selected checkpoint.
// The Rust adapter locates gas cutoffs without deriving expected state from them.
module fuzz {
  import storage_inputs.* from "./storage_inputs"
  import storage_metadata_inputs.* from "./storage_metadata_inputs"
  import types.* from "../../../../../vendor/polkadot-sdk-quint/designs/parachain-service-on-jam/quint/types"
  import messages.* from "../../../../../vendor/polkadot-sdk-quint/designs/parachain-service-on-jam/quint/messages"
  import state.* from "../../../../../vendor/polkadot-sdk-quint/designs/parachain-service-on-jam/quint/state"
  import state_vars.* from "../../../../../vendor/polkadot-sdk-quint/designs/parachain-service-on-jam/quint/state_vars"
  import head_commitment.* from "../../../../../vendor/polkadot-sdk-quint/designs/parachain-service-on-jam/quint/head_commitment"
  import transfer_inputs.* from "./transfer_inputs"
  import validator_key_inputs.* from "./validator_key_inputs"

  var replayGasLimits: List[int]
  var replayInterrupt: int
  action replayInit = all { storageInit, replayGasLimits' = List(),
    replayInterrupt' = -1 }

  action recover(budget: int, mode: int, stop: int, count: int, amount: int): bool = {
    val parent = svc.paraInfo(AssetHubParaId).headData
    // Alternate empty and eight-byte heads so deposit growth remains reachable.
    val newHead = if (parent == 0) now + 1 else 0
    val kv = storageWork(parent, newHead, 9, 256, 0)
    val metadata = metadataWork(CoretimeParaId, List(
      ParachainSetStateBalance({ paraId: MkParaId(3), newTotal: 1073741824 }),
      ParachainSetHead({ paraId: MkParaId(3), newHead: now + 1 })))
    val staging = metadataWork(AssetHubParaId, List(SetValidatorKeys({
      keys: List(now + 1), isLast: false })))
    val packages = if (mode == 0) List(kv, storageWork(newHead, now + 2, 10, 1, 0))
      else if (mode == 1) List(metadata, staging) else List(staging, kv)
    val incoming = range(0, count).foldl(List(), (a, i) => a.append({
      source: MkServiceId(7), amount: amount, toSupervisorBalance: false, memo: i }))
    val start: Host = { state: svc, free: budget, logs: replayStorageLogs,
      sizes: replayStorageSizes, failed: List(), failedMessages: List() }
    val arrived = if (stop == -2) { ...start, free: budget + count * amount }
      else arrivals(start, incoming, now + 1)
    val end = if (stop == -2) 0 else if (stop == -1) packages.length() else stop
    val out = range(0, end).foldl(arrived, (a, i) => report(a, packages[i], i, now + 1))
    all {
      svc' = out.state, prevSvc' = svc, now' = now + 1,
      lastStepWorkResults' = packages, lastStepAssigns' = List(), lastStepAssignBudget' = FullAssignBudget,
      lastHeadRoot' = if (stop == -1) headCommitment(svc, out.state) else None,
      solicitedSet' = solicitedSet, jamStagingSet' = jamStagingSet,
      foreignServices' = foreignServices, logPrunedBelow' = logPrunedBelow,
      replayIncoming' = incoming, replayStorageBudget' = budget,
      replayStorageFree' = out.free, replayStorageLogs' = out.logs,
      replayStorageSizes' = out.sizes, replayFailedHeads' = out.failed,
      replayFailedMessages' = out.failedMessages, noDesignation,
      replayGasLimits' = List(18446744073709551615, 18446744073709551615),
      replayInterrupt' = stop
    }
  }
  action randomStep = {
    nondet budget = Set(0, 7, 8, 60, 61, 100, 188, 253, 335, 336, 381, 382, 1000).oneOf()
    nondet mode = Set(0, 1, 2).oneOf()
    nondet stop = Set(-2, -1, 0, 1, 2).oneOf()
    nondet count = Set(0, 1, 3).oneOf()
    nondet amount = Set(0, 1, 64).oneOf()
    recover(budget, mode, stop, count, amount)
  }
  // Keep the head-growth/recovery intersection reachable without incoming
  // credits accidentally funding it. First retain a shrink, then reject growth.
  action headGrowthStep = recover(0, 0,
    if (svc.paraInfo(AssetHubParaId).headData == 0) 2 else 1, 0, 0)
  action replayStep = any { randomStep, headGrowthStep }
  run queue_recovery_works = replayInit
    .then(recover(188, 0, -2, 1, 1))
    .then(recover(188, 0, 0, 1, 0))
    .then(recover(100, 0, 1, 0, 0))
    .then(recover(7, 0, 2, 0, 0))
    .then(recover(1000, 0, -1, 1, 64))
  run metadata_recovery_works = replayInit
    .then(recover(60, 1, 1, 0, 0))
    .then(recover(1000, 1, 0, 0, 0))
    .then(recover(1000, 1, 1, 0, 0))
    .then(recover(335, 1, 2, 0, 0))
    .then(recover(1000, 1, -1, 0, 0))
  run staging_recovery_works = replayInit
    .then(recover(381, 2, 1, 0, 0))
    .then(recover(382, 2, 0, 0, 0))
    .then(recover(382, 2, 1, 0, 0))
    .then(recover(335, 2, 2, 0, 0))
    .then(recover(1000, 2, -1, 0, 0))
}
