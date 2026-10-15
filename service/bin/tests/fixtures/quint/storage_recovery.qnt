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
    recoverPackages(budget, stop, packages, incoming, List())
  }

  action recoverPackages(budget: int, stop: int, packages: List[WorkResult],
    incoming: List[IncomingTransfer], designated: List[ValidatorKey]): bool = {
    val start: Host = { state: svc, free: budget, logs: replayStorageLogs,
      sizes: replayStorageSizes, failed: List(), failedMessages: List() }
    val arrived = if (stop == -2) { ...start, free: budget + incoming.foldl(0, (n, t) => n + t.amount) }
      else arrivals(start, incoming, now + 1)
    val end = if (stop == -2) 0 else if (stop == -1) packages.length() else stop
    val out = range(0, end).foldl(arrived, (a, i) => report(a, packages[i], i, now + 1))
    all {
      svc' = out.state, prevSvc' = svc, now' = now + 1,
      lastStepWorkResults' = packages, lastStepAssigns' = List(), lastStepAssignBudget' = FullAssignBudget,
      lastHeadRoot' = if (stop == -1) headCommitment(svc, out.state) else None,
      solicitedSet' = solicitedSet,
      jamStagingSet' = if (end > 0 and designated != List()) designated else jamStagingSet,
      foreignServices' = foreignServices, logPrunedBelow' = logPrunedBelow,
      replayIncoming' = incoming, replayStorageBudget' = budget,
      replayStorageFree' = out.free, replayStorageLogs' = out.logs,
      replayStorageSizes' = out.sizes, replayFailedHeads' = out.failed,
      replayFailedMessages' = out.failedMessages,
      replayDesignate' = if (end > 0) designated else List(),
      replayGasLimits' = packages.foldl(List(), (a, _) => a.append(18446744073709551615)),
      replayInterrupt' = stop
    }
  }
  action balanceRecovery(budget: int, total: int, stop: int): bool =
    recoverPackages(budget, stop, List(metadataWork(CoretimeParaId, List(
      ParachainSetStateBalance({ paraId: MkParaId(3), newTotal: total })))), List(), List())

  // The final chunk is assembled in memory. Clearing the buffer releases its
  // deposit; even zero spare balance must allow a valid designation to commit.
  action validatorRecovery(budget: int, count: int, final: bool, stop: int): bool = {
    val chunk = range(0, count).foldl(List(), (a, i) => a.append(now + i))
    val designated = if (final) svc.stagedValidatorKeys.concat(chunk) else List()
    all {
      not(final) or ValCount.contains(designated.length()),
      recoverPackages(budget, stop, List(metadataWork(AssetHubParaId, List(
        SetValidatorKeys({ keys: chunk, isLast: final })))), List(), designated)
    }
  }
  action balanceStep = {
    nondet boundary = Set(1073741824, 4294967296, 1099511627776,
      281474976710656, 72057594037927936).oneOf()
    nondet grow = Set(false, true).oneOf()
    nondet budget = Set(0, 1, 1000).oneOf()
    nondet stop = Set(-2, -1, 0, 1).oneOf()
    balanceRecovery(budget, if (grow) boundary else boundary - 1, stop)
  }
  action validatorStep = {
    nondet stop = Set(-2, -1, 0, 1).oneOf()
    val count = svc.stagedValidatorKeys.length()
    // Cycle through a funded staging write and a zero-headroom finalization.
    if (count == 0) validatorRecovery(1726, 5, false, stop)
    else if (count == 5) validatorRecovery(0, 1, true, stop)
    else recover(1000, 0, stop, 0, 0)
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
  action replayStep = any { randomStep, headGrowthStep, balanceStep, validatorStep }
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
  run balance_u30_recovery_works = replayInit
    .then(balanceRecovery(1000, 1073741823, -1))
    .then(balanceRecovery(0, 1073741824, -2))
    .then(balanceRecovery(0, 1073741824, 0))
    .then(balanceRecovery(0, 1073741824, 1))
    .then(balanceRecovery(1, 1073741824, 0))
    .then(balanceRecovery(1, 1073741824, 1))
    .then(balanceRecovery(0, 1073741823, 0))
    .then(balanceRecovery(0, 1073741823, 1))
    .then(balanceRecovery(1, 1073741824, -1))

  run balance_u32_recovery_works = replayInit
    .then(balanceRecovery(1000, 4294967295, -1))
    .then(balanceRecovery(0, 4294967296, -2))
    .then(balanceRecovery(0, 4294967296, 0))
    .then(balanceRecovery(0, 4294967296, 1))
    .then(balanceRecovery(1, 4294967296, 0))
    .then(balanceRecovery(1, 4294967296, 1))
    .then(balanceRecovery(0, 4294967295, 0))
    .then(balanceRecovery(0, 4294967295, 1))
    .then(balanceRecovery(1, 4294967296, -1))

  run balance_u40_recovery_works = replayInit
    .then(balanceRecovery(1000, 1099511627775, -1))
    .then(balanceRecovery(0, 1099511627776, -2))
    .then(balanceRecovery(0, 1099511627776, 0))
    .then(balanceRecovery(0, 1099511627776, 1))
    .then(balanceRecovery(1, 1099511627776, 0))
    .then(balanceRecovery(1, 1099511627776, 1))
    .then(balanceRecovery(0, 1099511627775, 0))
    .then(balanceRecovery(0, 1099511627775, 1))
    .then(balanceRecovery(1, 1099511627776, -1))

  run balance_u48_recovery_works = replayInit
    .then(balanceRecovery(1000, 281474976710655, -1))
    .then(balanceRecovery(0, 281474976710656, -2))
    .then(balanceRecovery(0, 281474976710656, 0))
    .then(balanceRecovery(0, 281474976710656, 1))
    .then(balanceRecovery(1, 281474976710656, 0))
    .then(balanceRecovery(1, 281474976710656, 1))
    .then(balanceRecovery(0, 281474976710655, 0))
    .then(balanceRecovery(0, 281474976710655, 1))
    .then(balanceRecovery(1, 281474976710656, -1))

  run balance_u56_recovery_works = replayInit
    .then(balanceRecovery(1000, 72057594037927935, -1))
    .then(balanceRecovery(0, 72057594037927936, -2))
    .then(balanceRecovery(0, 72057594037927936, 0))
    .then(balanceRecovery(0, 72057594037927936, 1))
    .then(balanceRecovery(1, 72057594037927936, 0))
    .then(balanceRecovery(1, 72057594037927936, 1))
    .then(balanceRecovery(0, 72057594037927935, 0))
    .then(balanceRecovery(0, 72057594037927935, 1))
    .then(balanceRecovery(1, 72057594037927936, -1))

  run validator_finalization_recovery_works = replayInit
    .then(validatorRecovery(1725, 5, false, 1))
    .then(validatorRecovery(1726, 5, false, -1))
    .then(validatorRecovery(0, 1, true, -2))
    .then(validatorRecovery(0, 1, true, 0))
    .then(validatorRecovery(0, 1, true, 1))
    .then(validatorRecovery(1726, 5, false, -1))
    .then(validatorRecovery(0, 1, true, -1))

}
