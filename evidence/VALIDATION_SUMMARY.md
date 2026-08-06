# Sky IlkRegistry terminal-offboarding bypass — validation summary

## Executive conclusion

The production IlkRegistry at `0x5a464C28D19848f44199D003BeF5ecc87d090F87` has no governance-controlled terminal state for an ilk. Permissionless `add(address)` therefore cannot distinguish:

1. a temporary metadata/module refresh that is expected to be followed by re-addition; and
2. an authorized removal whose stated purpose is to finalize collateral offboarding.

This is not only a documentation mismatch. A real governance cleanup can be executed and materially reversed before the same transaction returns, the same 31 removed legacy records remain restorable in the pinned current state, public users cannot remove the restored live records, and the poisoned Registry propagates into deployed `OmegaPoker` automation and `Vat.spot` updates.

No debt reopening, fund theft, keeper payout extraction, or block-gas denial of service is claimed.

## Production root cause

`add(address)` is permissionless and accepts an adapter when it:

- points to the production Vat;
- remains authorized in Vat;
- reports an ilk absent from Registry;
- has a non-zero Spotter oracle pointer; and
- has a non-zero Dog clip or Cat flip pointer.

The function does not check whether governance has terminally offboarded the ilk. It also does not check `Join.live()`.

The official unit tests demonstrate a valid temporary `removeAuth -> add` refresh use case. The defect is that this temporary state is indistinguishable from a governance-authorized final removal.

## Real governance baseline

The August 7, 2025 executive proposal stated that selected offboarded ilks would be removed from IlkRegistry to finalize offboarding.

The real spell at `0x26009aFf7fE39bF7611d66E0D38CAc43b3A93CD5` executed 42 `removeAuth` calls. On fork block `23,118,263`, exactly one block before the real cast:

```text
pre-cast Registry count: 72
clean post-cast Registry count: 30
removed records: 42
```

## Atomic governance-result reversal

Test: `src/IlkRegistryAtomicGovernanceReversal.t.sol`

One unprivileged helper call performs, in one external transaction:

1. public `spell.cast()` on the real approved spell; and
2. permissionless `registry.add(adapter)` for the recorded legacy Join adapters.

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

The transaction that executes the approved cleanup returns with `AAVE-A`, `USDC-A`, `ZRX-A`, and 28 other removed standard ilks already registered again. No mempool race, privileged key, malicious proposal, or miner cooperation is required.

Workflow run: `31082020451`.

## Independent historical mass-restoration control

Test: `src/IlkRegistryMassReAdd.t.sol`

```text
[PASS] testAttackerMassReAddsGovernanceRemovedIlks()
governance removals reversed 31
re-added adapters still live 31
cleaned count 30
post-attack count 61
```

Workflow run: `31079596605`.

## Pinned current-state exploitability

Test: `src/IlkRegistryCurrentMassReAdd.t.sol`

Pinned block: `25,694,337`.

```text
initial Registry count: 35
successful legacy additions: 31 / 31
post-attack Registry count: 66
all 31 Join adapters live: yes
all 31 Join adapters Vat-authorized: yes
restored ilks with non-zero Art or line: 0
```

The test asserts every adapter and target individually; it does not infer addability from partial state checks.

### Residual-debt negative control

`RWA012-A` and `RWA013-A` each have residual `Art == 1` and `line == 0` at the same pinned block. Both are absent from Registry, but both production `add()` calls revert with:

```text
IlkRegistry/invalid-auction-contract
```

Therefore residual-debt RWA restoration is explicitly excluded from the impact claim.

## Deployed downstream propagation: OmegaPoker and Vat

Test: `src/IlkRegistryOmegaPokerImpact.t.sol`

Deployed consumer: `OmegaPoker` at `0xDd538C362dF996727054AC8Fb67ef5394eC9b8b9`.

`OmegaPoker.refresh()` consumes `registry.list()`, caches Registry ilks and OSMs, and `OmegaPoker.poke()` invokes the cached oracle/Spotter paths.

Differential result at block `25,694,337`:

```text
Registry count:                 35 -> 66
OmegaPoker ilk count:           12 -> 38
OmegaPoker OSM count:            7 -> 32
restored legacy ilks cached:          26
refresh gas:                775,934 -> 2,329,157
poke gas:                   600,720 -> 2,145,661
legacy Vat.spot values changed:      15
legacy Vat.spot values non-zero:     31
```

The 15 changed ilks were:

- `CRVV1ETHSTETH-A`
- `GNO-A`
- `KNC-A`
- `LINK-A`
- `RENBTC-A`
- `UNIV2AAVEETH-A`
- `UNIV2DAIETH-A`
- `UNIV2DAIUSDT-A`
- `UNIV2ETHUSDT-A`
- `UNIV2LINKETH-A`
- `UNIV2UNIETH-A`
- `UNIV2USDCETH-A`
- `UNIV2WBTCDAI-A`
- `UNIV2WBTCETH-A`
- `USDT-A`

This proves the result is not limited to a UI or an unused Registry array. Unprivileged Registry restoration changes the work set of deployed automation and causes state changes in core Vat metadata. Because these ilks retain `line == 0`, this is presented as material downstream propagation, not debt reopening.

Workflow runs: `31084333998` and `31084770021`.

## Persistence and mitigation constraints

Test: `src/IlkRegistryPersistence.t.sol`

```text
[PASS] testRestoredLiveIlksCannotBePubliclyRemoved()
restored entries 31
public removals blocked by live joins 31
registry count after removal attempts 66

[PASS] testCagingJoinDoesNotPermanentlyBlockReAdd()

[PASS] testDenyBlocksBothReAddAndCollateralExit()
AAVE Join external collateral balance 77.033778046632910564 AAVE
```

Consequences:

- after restoration, public `remove()` cannot remove any of the 31 entries because the adapters remain live;
- caging does not create a terminal state because a caged adapter can still be repeatedly `add -> remove -> add`;
- `Vat.deny(join)` blocks Registry addition, but the same authorization is required by `GemJoin.exit()`;
- the AAVE adapter still held collateral, so denying it is not a harmless universal cleanup action.

Governance can still repair the state through a new privileged action. The finding is that the existing removal did not create the terminal state its stated purpose required.

Workflow run: `31081065745`.

## Keeper impact measured and bounded

Test: `src/IlkRegistryKeeperGas.t.sol`

- all nine active dss-cron jobs retained the same call-success and `canWork == false` result;
- no paid/executable work was created;
- maximum individual gas increase was approximately 1.50 million gas;
- `Sequencer.getNextJobs()` increased from approximately 5.88 million to 8.56 million gas;
- measured block gas limit was approximately 60 million.

This is bounded gas grief evidence only. Keeper-payment extraction and block-gas DoS are not claimed.

Workflow run: `31080500141`.

## Architectural evidence and negative historical control

A May 2022 governance spell iterated over `IlkRegistry.list()` to authorize the replacement End contract on each liquidation module and whitelist it on each oracle. This demonstrates that Registry enumeration is trusted governance configuration, not merely display metadata.

A fork scan immediately before that spell's real cast found zero absent historical Join adapters accepted by production `add()`. Therefore no exploit is claimed against that particular spell.

## Explicitly falsified or excluded theories

The report must not claim:

1. a `remove -> removeAuth` front-run against the August 2025 cleanup spell — none of its 42 targets was publicly removable before cast;
2. a naturally caged addable adapter in current production — the confirmed 31 adapters are live;
3. a second historical Join that substitutes a different gem for the same ilk — none was found;
4. residual-debt RWA restoration — the two residual-Art controls revert;
5. direct debt reopening, theft, protocol insolvency, keeper payout extraction, or block-gas DoS.

## Recommended remediation

A `Join.live()` check alone is insufficient because the 31 affected adapters remain live to preserve collateral exit.

The Registry needs a governance-controlled terminal tombstone, for example:

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

Terminal offboarding spells should call `blockIlk`, while temporary refresh flows may continue using `removeAuth -> add`.

Separately:

- enforce the documented active-adapter condition where compatible with intended lifecycle behavior; and
- validate key existence plus array/mapping consistency inside `_remove` before swap-and-pop.
