# Triage objection matrix

This document separates confirmed behavior from severity interpretation and prepares concise answers to the strongest likely objections.

## 1. “IlkRegistry is intentionally publicly modifiable”

### Accurate part of the objection

Yes. Permissionless addition is an explicit Registry design choice, and official unit tests allow `removeAuth -> add` during technical metadata/module refreshes.

### Why the finding remains valid

The same state transition was also used by governance for a different lifecycle action: removal of offboarded collateral records to finalize offboarding. The Registry has no terminal/tombstoned state, so permissionless code cannot distinguish the temporary refresh use case from the final offboarding use case.

The PoC does not argue that all permissionless additions are invalid. It demonstrates that a final governance removal is not final and can be reversed before the transaction executing the approved spell returns.

### Evidence

- Real proposal states removal is part of finalizing offboarding.
- Clean spell result: `72 -> 30`.
- One unprivileged transaction: `72 -> 30 -> 61`, with `spell.done() == true`.

## 2. “Official tests explicitly perform removeAuth followed by add”

### Accurate part of the objection

Correct. That proves temporary refresh is an intended use case.

### Response

It does not prove that an authorized terminal removal may be reversed by any address. Instead, it establishes the two distinct lifecycle meanings that the contract fails to represent:

- temporary absence pending refresh; and
- terminal absence following offboarding.

A tombstone preserves the first use case while protecting the second.

## 3. “This is only a badly composed historical spell”

### Response

The historical spell provides a concrete governance baseline, but the vulnerable state machine resides in the current production Registry:

- at pinned current block `25,694,337`, 31 removed legacy records are still independently accepted by production `add()`;
- no historical spell execution is required for that current restoration;
- public users cannot remove the restored records because the Join adapters remain live;
- deployed OmegaPoker consumes the poisoned Registry and propagates it into `Vat.spot` updates.

The historical spell is therefore a proof of an already-realized lifecycle mismatch, not the sole vulnerable component.

## 4. “The report is a feature request for a tombstone”

### Response

The requested property is not newly invented behavior. Governance already used `removeAuth` and publicly described the action as finalizing offboarding. The present implementation fails to preserve that authorized result.

The tombstone is one remediation. The vulnerability is the demonstrated unprivileged reversal and downstream propagation, not the absence of a preferred API shape by itself.

## 5. “There is no theft or debt reopening”

### Response

Agreed. The report does not select theft, insolvency, or debt reopening as its impact.

The selected impact is the program's governance-result deviation category. The objective state difference is:

```text
approved clean result: 30 Registry entries
attacker-controlled result: 61 Registry entries
spell.done(): true in both cases
```

OmegaPoker additionally proves that the difference is consumed on-chain and modifies core Vat metadata.

## 6. “Changing Vat.spot is harmless because line is zero”

### Response

The report does not claim immediate borrowing or liquidation from the spot changes. The point of the OmegaPoker test is narrower and objective: the Registry modification is not cosmetic; it changes a deployed automation work set and causes state changes in Vat for 15 retired ilks.

The governance-result deviation remains the severity driver.

## 7. “The restored records can simply be removed again”

### Response

Not by an unprivileged caller. All 31 adapters remain `live == 1`, while public `remove()` requires a caged adapter. A fork test attempts all 31 removals and all 31 are blocked.

A new governance action can repair the state, but the original governance action did not create a terminal result.

## 8. “Governance can cage the Join”

### Response

Caging alone does not block `add()`. The test proves a caged adapter can be repeatedly:

```text
add -> remove -> add
```

because `add()` does not check `Join.live()`.

A `live` check would improve this caged case, but it would not prevent current restoration of the 31 live adapters.

## 9. “Governance can deny the Join in Vat”

### Response

`Vat.deny(join)` blocks Registry addition, but `GemJoin.exit()` uses the same Vat authorization through `Vat.slip`. The test proves `exit()` reverts with `Vat/not-authorized` after deny.

The AAVE Join held approximately `77.033778 AAVE` on the pinned fork, so this is not a universal zero-balance cleanup operation.

The report does not claim that governance has no possible remediation. It claims that no existing Registry terminal state simultaneously preserves necessary exit authorization and prevents re-addition.

## 10. “The affected ilks are empty”

### Response

The 31 positively proven restorable ilks have `Art == 0` and `line == 0`; this is explicitly disclosed.

The security claim is governance-result reversal and trusted-config propagation, not funds at risk through those ilks. Residual-Art RWA candidates were separately tested and rejected by production `add()`; they are not included.

## 11. “The effect is only gas grief”

### Response

No. Keeper gas was measured separately and bounded. The primary effect is:

- atomic reversal of 31 authorized removals;
- persistent unprivileged restoration in current production state;
- OmegaPoker cache expansion; and
- 15 `Vat.spot` state changes.

Keeper gas is included only as counterevidence against overstating DoS.

## 12. “A malicious governance spell is required”

### Response

No. The PoC calls the real, already-approved historical spell unchanged. `cast()` is public after its governance delay. The attacker contributes only an unprivileged helper transaction that invokes the legitimate spell and then calls permissionless `add()`.

This does not rely on governance approving malicious code and therefore does not match the program's malicious-spell exclusion.

## 13. “A privileged address is required”

### Response

No attacker privilege is used:

- `spell.cast()` is public when executable;
- `IlkRegistry.add(address)` is public;
- `OmegaPoker.refresh()` and `poke()` are public.

The PoC does not impersonate Pause Proxy or a ward for the exploit path. Privileged impersonation appears only in separate mitigation tests that evaluate governance's available options.

## 14. “This is old and already mitigated”

### Response

The historical spell establishes the voted baseline, but current exploitability is independently pinned at block `25,694,337`:

```text
Registry: 35 -> 66
successful additions: 31 / 31
```

The relevant Registry is still the production deployment, and the same adapters remain accepted.

## 15. “IlkRegistry may not be an individually listed asset”

### Response

The report should select the closest Core System/DSS target and explicitly identify the exact deployed address and matching `sky-ecosystem/ilk-registry` source. The program contains the governance-result impact and covers deployed Sky core contracts through its listed core-system/Chainlog surface.

This remains a scope-classification risk and should be stated rather than hidden.

## 16. “Mainnet testing violates program rules”

### Response

All state-changing validation was performed on local Ethereum forks. No mainnet or public-testnet transactions were sent.

## 17. “The PoC contains contradictory failed theories”

### Response

The submission package must exclude all falsified race PoCs and flawed exploratory scans. The canonical branch now excludes the old `IlkRegistryAtomicRace.t.sol` and the disproven pre-removal theory.

The report's excluded-claims section explicitly records the negative findings.

## 18. “The PoC is not reproducible because public RPCs rate-limit”

### Response

Every primary proof uses a pinned block and deterministic assertions. The package includes machine logs from successful runs and a sequential RPC-failover workflow. Standard `forge build` succeeds without `--via-ir` or custom compiler settings.

Researchers reproducing locally should use an archive-capable RPC with sufficient rate limits.

## Recommended triage framing

The report should not ask triage to accept a broad statement that public Registry mutation is always forbidden. It should ask a narrower question:

> Can an unprivileged caller cause the transaction executing an approved, terminal offboarding cleanup to return with 31 of the removed records restored, while `spell.done()` is true, and can the same records still be restored in the current production state and propagated into deployed automation?

The fork evidence answers that question yes.
