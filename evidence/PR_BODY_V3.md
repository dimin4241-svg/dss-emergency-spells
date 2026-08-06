# Repeatable public veto of governance IlkRegistry removal

Private audit harness for a production Sky IlkRegistry lifecycle issue.

## Primary historical proof

At block `23,118,263`, one arbitrary external call executes the real approved spell and restores 31 of its 42 removed records before returning:

```text
clean governance result       72 -> 30
public caller final result    72 -> 30 -> 61
spell.done()                  true
restored records              31
```

## Strongest current proof

At block `25,694,337`, production `add()` accepts 31/31 removed legacy adapters.

A repeated-veto test alternates legitimate governance removal with public re-addition:

```text
governance removeAuth cycles       3
successful public re-adds          4
final AAVE-A in Registry        true
final AAVE-A in OmegaPoker      true
attacker add gas total       758,204
Join live / Vat ward              1 / 1
```

The arbitrary caller controls the final canonical target-set state after every cleanup-only governance action.

## Persistence

- public removal is blocked for all 31 restored live Joins;
- caging alone is not terminal because `add()` ignores `Join.live()`;
- `Vat.deny(join)` blocks add but also makes `GemJoin.exit()` revert;
- the AAVE Join still held collateral at the pinned state.

## Confirmed counterevidence

A focused differential test proves that `MCD_VAT.spot` is not a unique Registry consequence:

```text
LINK-A baseline                         72000000000000000000000000
direct oracle + Spotter result          145650900000000000000000000
Registry + Omega result                 145650900000000000000000000
final values equal                      true
```

Therefore the report does not claim MCD_VAT impact, Chainlog inconsistency, debt reopening, active-auction loss, theft, insolvency, fund freezing, or emergency DoS.

## Scope risk

Current Sky rules state that governance/permissionless action grouping is assumed to be implemented at the spell or `dss-exec-lib` layer. This is the strongest rejection path.

The surviving submission theory is only:

> An arbitrary address can repeatedly veto the exact IlkRegistry absence postcondition approved by governance because the deployed Registry has no terminal lifecycle state.

See:

- `evidence/IMMUNEFI_REPORT.md`
- `evidence/TRIAGE_RED_TEAM.md`
- `evidence/TRIAGE_OBJECTION_MATRIX.md`
- `evidence/VALIDATION_SUMMARY.md`
- `evidence/FINAL_ASSESSMENT.md`

This remains a private audit branch and is not intended for upstream merging.
