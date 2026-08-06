# Sky IlkRegistry terminal-offboarding bypass — validation summary

## Confirmed production behavior

The production IlkRegistry at `0x5a464C28D19848f44199D003BeF5ecc87d090F87` exposes permissionless `add(address)`.

`add` accepts an adapter when it:

- points to the production Vat;
- remains a Vat ward;
- reports an ilk that is absent from Registry;
- has a non-zero Spotter pip;
- has a Dog clip or Cat flip.

It does not distinguish a new onboarding or technical metadata refresh from an ilk that governance explicitly removed to finalize offboarding. There is no tombstone or terminal-offboarding state.

## Real governance baseline

The August 7, 2025 executive proposal explicitly stated that offboarded ilks would be removed from IlkRegistry to finalize offboarding.

The real spell at `0x26009aFf7fE39bF7611d66E0D38CAc43b3A93CD5` called `removeAuth` for 42 records. The official Sky spell test establishes the clean baseline:

- pre-cast count: 72;
- post-cast count: 30;
- all 42 selected records removed.

Fork block used by the PoCs: `23,118,263`, exactly one block before the real cast.

## Confirmed atomic governance-result reversal

Test: `src/IlkRegistryAtomicGovernanceReversal.t.sol`

A helper contract, called by an unprivileged account, performs in one external transaction:

1. `spell.cast()` on the real approved spell;
2. permissionless `registry.add(adapter)` for each recorded legacy Join.

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

The transaction that executes the approved cleanup returns with 31 of the removed standard ilks already registered again. Representative assertions confirm `AAVE-A`, `USDC-A`, and `ZRX-A` are present before control returns to the external caller.

Workflow run: `31082020451`.

## Confirmed historical mass restoration

Test: `src/IlkRegistryMassReAdd.t.sol`

Machine result after independently casting the same real spell:

```text
[PASS] testAttackerMassReAddsGovernanceRemovedIlks()
governance removals reversed 31
re-added adapters still live 31
cleaned count 30
post-attack count 61
```

Workflow run: `31079596605`.

## Confirmed current-mainnet exploitability

Test: `src/IlkRegistryCurrentMassReAdd.t.sol`

At fork block `25,694,337`:

```text
[PASS] testCurrentMainnetOneTransactionRestoresRemovedIlks()
initial registry count 35
restored in one transaction 31
post-attack registry count 66
gas used by test body 8,970,454
restored with nonzero Art or line 0
```

All 31 adapters were still:

- `live == 1`;
- authorized in the production Vat;
- absent from Registry;
- backed by non-zero pip and liquidation-contract pointers.

Workflow run: `31080086181`.

## Confirmed persistence and incomplete companion actions

Test: `src/IlkRegistryPersistence.t.sol`

Machine result:

```text
[PASS] testRestoredLiveIlksCannotBePubliclyRemoved()
restored entries 31
public removals blocked by live joins 31
registry count after removal attempts 66

[PASS] testCagingJoinDoesNotPermanentlyBlockReAdd()

[PASS] testDenyBlocksBothReAddAndCollateralExit()
AAVE Join external collateral balance 77033778046632910564
AAVE token decimals 18
```

Consequences:

- permissionless `remove` cannot undo the current restoration because all restored Join adapters are live;
- caging a Join is not a terminal fix because `add` does not check `Join.live()`; after `add -> remove`, the caged adapter can be added again;
- denying the Join in Vat blocks `add`, but also disables the Join's `exit` path;
- the AAVE Join held approximately `77.033778046632910564 AAVE` during the current fork, so disabling exit is not a zero-balance theoretical concern.

Workflow run: `31081065745`.

## Keeper impact measured and bounded

Test: `src/IlkRegistryKeeperGas.t.sol`

After restoring the 31 ilks on a current-mainnet fork:

- all nine active jobs retained the same call success and `canWork == false` result;
- no paid/executable keeper work was created;
- maximum individual gas increase was approximately 1.50 million gas;
- `Sequencer.getNextJobs()` increased from approximately 5.88 million to 8.56 million gas;
- the measured block gas limit was approximately 60 million.

Therefore the keeper effect is measurable gas grief, not a demonstrated keeper-payment extraction or block-gas denial of service.

Workflow run: `31080500141`.

## Explicitly falsified theories

The following claims must not be included as proven impact:

1. **Historical `remove -> removeAuth` front-run against the 2025 cleanup spell.**
   Machine scanning showed none of the 42 real cleanup targets was publicly removable before cast. Standard Join adapters were still live; custom/RWA entries were not eligible for public removal.

2. **A naturally caged adapter is currently addable.**
   Current production scanning found 31 addable live adapters and zero naturally caged addable adapters.

3. **A second historical Join can substitute a different gem for the same symbolic ilk.**
   Full spell-archive scanning found no `MCD_JOIN_*` symbol with multiple historical addresses.

4. **Direct Vat debt reopening or paid keeper work.**
   All 31 restored ilks had `Art == 0` and `line == 0`; keeper job outcomes did not become executable.

## Security interpretation

The strongest impact is not debt reopening. It is a state-machine failure between two legitimate Registry use cases:

- temporary remove/re-add for metadata or module refresh; and
- governance-authorized terminal removal to finalize offboarding.

Because the Registry has no terminal state, the latter is indistinguishable from the former. An unprivileged caller can cause the transaction executing the approved spell to end in a state materially different from the proposal's stated cleanup outcome.

## Recommended fix

A `Join.live()` check alone is insufficient: the 31 relevant adapters are intentionally still live to preserve collateral exit.

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

The offboarding spell should call `blockIlk`, not only `removeAuth`.

Separately, `add` should enforce the documented active-adapter condition when appropriate, and `_remove` should validate existence and array/mapping consistency before swap-and-pop.
