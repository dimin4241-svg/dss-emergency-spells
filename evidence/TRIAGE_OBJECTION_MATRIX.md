# Revised triage objection matrix

This matrix reflects the adversarial controls. It does not defend claims that the controls disproved.

## 1. “IlkRegistry is intentionally publicly modifiable”

**Accurate.** The official README says so, and official tests support `removeAuth -> add` for technical refresh.

**Surviving response:** the finding is narrower. Governance used the same removal operation for a stated terminal purpose—removing named offboarded ilks to finalize offboarding. The contract has no state that distinguishes that terminal removal from temporary refresh.

## 2. “The vote and spell executed correctly; the attacker only made a later allowed call”

**Strong objection.** `DssExec.done()` is only a cast flag, not a postcondition checker. Atomic transaction composition does not change the authorization of each call.

**Surviving response:** the attacker may call the real executable spell and restore 31 targets before the same external transaction returns. More importantly, the current repeated-veto PoC proves the issue independently of the old spell: after each legitimate `removeAuth`, a public caller restores the target and chooses the final Registry/Omega membership state.

## 3. “Sky assumes governance and permissionless actions are grouped at spell level”

**Strongest scope objection.** Current rules expressly say this grouping is assumed to be implemented in the spell or `dss-exec-lib`.

**Response:** the deployed Registry still lacks a terminal state, and the repeated-veto behavior is current. However, triage may classify this as incomplete spell composition, especially because a spell can clear residual Spotter/Dog addability conditions. This objection may be dispositive.

## 4. “Chainlog inconsistency is explicitly a non-issue”

**Correct.** Current rules say missing/extra/wrong/inconsistent Chainlog values are assumed non-issues.

**Action:** do not use Chainlog retirement as the impact or severity driver. Chainlog may appear only as historical context.

## 5. “MCD_VAT.spot can be changed without Registry”

**Confirmed.** A focused differential control proves:

```text
LINK-A baseline                         72000000000000000000000000
direct legacy oracle + Spotter result  145650900000000000000000000
Registry + Omega result                145650900000000000000000000
final values equal                     true
```

**Action:** do not select `MCD_VAT` as the primary asset and do not claim Vat modification is caused uniquely by the Registry issue.

## 6. “Economic offboarding remains complete”

**Confirmed for the 31 addable ilks:**

- `Art == 0`;
- `line == 0`;
- no AutoLine configuration;
- no LineMom enablement;
- no active legacy Clipper auctions;
- no Clipper Vat collateral balance.

**Response:** the surviving claim is governance postcondition veto over canonical Registry/list-consumer membership, not economic reopening.

## 7. “The residual-Art RWA records make this severe”

**False.** `RWA012-A` and `RWA013-A` are rejected by production `add()` with `IlkRegistry/invalid-auction-contract`.

**Action:** retain them only as negative controls.

## 8. “The restored entries can simply be removed again”

**Not by a public caller.** All 31 Joins remain live; public `remove()` is blocked.

**Stronger proof:** the repeated-veto test alternates three legitimate governance `removeAuth` calls with four public re-additions. The attacker wins the final state for only `758,204` total add gas.

## 9. “Governance can cage the Join”

Caging does not create a terminal state because `add()` does not check `Join.live()`; `add -> remove -> add` remains possible.

## 10. “Governance can deny the Join in Vat”

Deny blocks re-add, but it also causes `GemJoin.exit()` to revert through `Vat.slip`. At least the AAVE Join still holds collateral.

**Limit:** governance can instead clear residual Spotter/Dog conditions or deploy a new Registry. The report must not claim remediation is impossible.

## 11. “Emergency-spell `done()` changes are expected for mutable target sets”

This is plausible. The tested entries are retired, but the contracts intentionally read the current Registry dynamically.

**Action:** use emergency results only to prove operational consumption of Registry membership. Do not present them as an independent Critical, fund freeze, or permanent DoS.

## 12. “Generic griefing/gas is not a listed Sky impact”

Correct based on the visible current impact table. The finite emergency re-execution burden does not independently map to an accepted impact.

## 13. “IlkRegistry/OmegaPoker may not be explicitly listed assets”

This remains a risk. The program says a Critical impact on any deployed Sky smart contract may be submitted for consideration, but without acceptance of the Critical governance impact there is no reliable fallback severity.

## 14. “This is a feature request for a tombstone”

A tombstone is only one fix. The technical defect is the inability of the existing authorized removal operation to establish a terminal state.

Nevertheless, because public addability is documented and spell composition is assumed, triage may still classify the requested terminal state as a feature request.

## 15. “This is not manipulation of a governance voting result”

This is the decisive interpretation question.

**For acceptance:** the proposal named exact records and said their removal would finalize offboarding. An arbitrary address can atomically reverse 31 removals and can repeatedly veto later `removeAuth` actions, choosing a final canonical target-set state different from the approved result.

**For rejection:** the vote winner and spell bytecode are unchanged; the attacker only uses a documented permissionless function after execution. The program may reserve the governance category for vote-result or privileged execution manipulation.

## Recommended submission framing

Use only this question:

> Can an arbitrary address repeatedly veto the exact IlkRegistry absence postcondition approved by governance, including by executing the real spell and restoring 31 removed records before the transaction returns, while the same public veto remains live in the current deployment?

Do not frame the submission around Chainlog, MCD_VAT, oracle access, debt reopening, emergency DoS, or financial loss.
