# Final validation assessment — after full triage red-team

## Disposition

**Technically validated behavior, but not recommended for submission as a normal bounty report under the current Sky rules.**

The public re-add and repeated-veto behavior is real. However, the program-specific counterevidence now gives triage a direct and reproducible reason to classify it as incomplete spell composition against an intentionally public Registry rather than a rewarded vulnerability.

## Technical confidence

- Production `add()` behavior and 31 current restorable records: **very high**
- Atomic real-spell `72 -> 30 -> 61` reproduction: **very high**
- Repeatable public re-add after governance `removeAuth`: **very high**
- Inability of public callers to remove restored live entries: **very high**
- Lifecycle/correctness weakness: **high**

## Decisive positive proof tuple

- **Caller:** arbitrary address.
- **Public entrypoint:** `IlkRegistry.add(address)`.
- **Historical result:** clean `72 -> 30`; public atomic final state `61`.
- **Current result:** production `add()` accepts 31/31 adapters at block `25,694,337`.
- **Repeated result:** three legitimate governance removals followed by four public re-additions; caller controls final Registry/Omega membership for `758,204` total add gas.
- **Persistence:** public removal is blocked because the Joins remain live.

## Decisive rejection proof tuple

1. IlkRegistry is officially documented as publicly modifiable.
2. Official tests support `removeAuth -> add` as a normal refresh workflow.
3. Current Sky rules assume governance actions and required permissionless companion actions are grouped at the spell or `dss-exec-lib` layer.
4. A production-fork control proves governance can safely clear the residual Spotter `pip`, making `add()` revert while preserving:
   - `Join.live() == 1`;
   - `Vat.wards(join) == 1`;
   - the Join's collateral custody balance; and
   - successful `GemJoin.exit()` authorization.
5. Direct public legacy-oracle `poke()` plus public `MCD_SPOT.poke()` produces the same tested `MCD_VAT.spot` value as Registry/Omega; Vat is not a unique causal sink.
6. Chainlog inconsistency is explicitly a non-issue under the program.
7. All positively restored ilks have zero Art and line.
8. No residual AutoLine, active auction, theft, insolvency, freeze, liquidation, or permanent DoS is demonstrated.
9. No visible listed Medium or Low impact fits the remaining target-set/configuration veto.

## Safe mitigation machine result

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

Workflow run: `31093768541`.

This makes the special Sky rule about spell-level composition directly applicable rather than theoretical.

## Estimated triage outcomes

These are judgment ranges, not guarantees:

- Technical behavior reproduced: **98–100%**
- Lifecycle/correctness weakness acknowledged: **60–80%**
- Accepted as the listed Critical governance impact: **1–5%**
- Any bounty: **2–8%**
- Rejected as intended public behavior, incomplete spell composition, feature request, or non-listed impact: **90–97%**

## Recommendation

Do not submit the old MCD_VAT/Chainlog v3 package.

The narrow governance-veto report can be retained as research evidence, but it is not a strong payout candidate after the safe mitigation control. Time is better spent on a different Sky finding with a direct listed impact.

If submitted despite the low odds, the report must:

- use IlkRegistry as the exact affected contract;
- disclose the spell-composition rule and safe mitigation control;
- avoid MCD_VAT, Chainlog, debt, auctions, freezing, and emergency gas as severity claims; and
- ask only whether repeatable public veto over the exact Registry absence postcondition qualifies as governance-result manipulation.
