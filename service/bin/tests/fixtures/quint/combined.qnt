// End-to-end scripts: model Refine predicts digests; model Accumulate predicts state.
module combined {
  import fuzz.* from "./fuzz"
  import types.* from "../../../../../vendor/polkadot-sdk-quint/designs/parachain-service-on-jam/quint/types"
  import messages.* from "../../../../../vendor/polkadot-sdk-quint/designs/parachain-service-on-jam/quint/messages"
  import state.* from "../../../../../vendor/polkadot-sdk-quint/designs/parachain-service-on-jam/quint/state"
  import state_vars.* from "../../../../../vendor/polkadot-sdk-quint/designs/parachain-service-on-jam/quint/state_vars"
  import refine_inputs.* from "./refine_inputs"

  def candidate(parent: int, mode: int): RefinedWork =
    replayCandidate(svc, CoretimeParaId, parent, activeCodeCandidate(svc, CoretimeParaId),
      mode, now, 7, List(SetKV({ key: List(1), value: List(parent + 1) })))

  run single_works = replayInit.then(refinedBlock(List(candidate(0, 0)), 1))
    .then(refinedBlock(List(candidate(1, 0)), 2))
  run ordered_batch_works = replayInit.then(refinedBlock(
    List(candidate(0, 0), candidate(1, 0), candidate(2, 0)), 1))
  run errors_works = replayInit.then(refinedBlock(
    List(candidate(0, 2), candidate(0, 4), candidate(0, 1)), 1))
    .then(refinedBlock(List(candidate(0, 0)), 2))
  run checkpoint_works = replayInit.then(checkpointBlockAt(1))
}
