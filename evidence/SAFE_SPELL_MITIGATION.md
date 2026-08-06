# Safe spell-level mitigation proof

## Purpose

This control tests the strongest triage response to the governance-veto report:

> The offboarding spell should have removed a public `add()` precondition, because current Sky rules assume necessary governance and permissionless actions are grouped at the spell or `dss-exec-lib` layer.

## Test

```text
src/IlkRegistrySafeSpellMitigation.t.sol
```

Pinned block:

```text
25,694,337
```

The test uses the production IlkRegistry, Spotter, Vat, AAVE Join, and Pause Proxy permissions.

Governance performs only:

```solidity
spotter.file("AAVE-A", "pip", address(0));
```

Then the test verifies:

1. production `IlkRegistry.add(AAVE_JOIN)` reverts with `IlkRegistry/pip-invalid`;
2. the AAVE Join remains live;
3. the AAVE Join remains a Vat ward;
4. the Join's external AAVE custody balance is unchanged; and
5. `GemJoin.exit()` still reaches its Vat authorization path successfully.

## Machine result

```text
[PASS] testGovernanceCanBlockReAddByClearingPipWithoutBreakingExit()
AAVE residual pip before                 0x8Df8f06DC2dE0434db40dcBb32a82A104218754c
AAVE residual pip after                  0x0000000000000000000000000000000000000000
AAVE Join Vat ward after mitigation      1
AAVE Join live after mitigation          1
AAVE Join custody before                 77033778046632910564
AAVE Join custody after                  77033778046632910564
public re-add blocked                     true
zero-amount exit still succeeds           true
```

Workflow run:

```text
31093768541
```

## Triage significance

This control disproves the claim that governance must add a Registry tombstone or revoke the Join's Vat authorization to prevent re-addition.

An existing spell-level privileged action safely prevents `add()` while preserving the collateral exit path. This makes the current Sky program's spell-composition assumption directly applicable and is the strongest reason the finding is unlikely to receive a bounty.
