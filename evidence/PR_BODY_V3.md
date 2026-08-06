# Atomic bypass of coordinated Sky oracle retirement reaches MCD_VAT

Private audit harness for a production Sky IlkRegistry lifecycle/state-machine issue.

## Strongest confirmed PoC

At block `23,118,263`, one unprivileged external call performs:

```text
real approved spell.cast()
-> 31 permissionless IlkRegistry.add() calls
-> deployed OmegaPoker.refresh()
-> deployed OmegaPoker.poke()
```

Before the call returns:

```text
approved spell.done()                         true
selected Chainlog oracle keys still retired     8
Registry records restored                      31
selected retired paths recached                  7
selected retired MCD_VAT.spot values changed     2
final Registry count                            61
call gas used                            13,401,327
block gas limit                          44,868,168
```

Clean governance result: `72 -> 30`.
Attacker-controlled result: `72 -> 30 -> 61`.

## Current-state proof

At pinned block `25,694,337`, one public call without a historical spell produces:

```text
Registry                     35 -> 66
retired records restored          31
retired paths recached            26
MCD_VAT.spot values changed       15
gas used                  11,175,460 / 60,000,000
```

## Deployed emergency-spell consequence

After legitimate clean completion, the same restored records make the production emergency spells incomplete again:

```text
MultiOsmStopSpell:     25 new obligations, done=false
MultiClipBreakerSpell: 30 new obligations, done=false
```

Staged additions force 25 and 30 repeated emergency response executions, respectively.

## Canonical validation

Workflow run `31089226913`:

- standard Solc build succeeded;
- 14 canonical cases passed;
- 0 assertion failures;
- positive proofs and negative controls ran sequentially with RPC failover.

## Package

Workflow run `31089526583` produced:

```text
sky-ilk-registry-governance-retirement-validation-v3.zip
SHA-256: 879f004191d2cc610296462b9fa9a75b02f665dc1ed110894aa49280f5fea842
```

The downloaded package was independently extracted and its included verifier returned `VALIDATION PASSED`.

## Explicit non-claims

No theft, insolvency, debt reopening, active-auction loss, residual AutoLine reopening, malicious governance proposal, privileged attacker access, or block-gas DoS is claimed.

See:

- `evidence/IMMUNEFI_REPORT.md`
- `evidence/TRIAGE_OBJECTION_MATRIX.md`
- `evidence/VALIDATION_SUMMARY.md`
- `evidence/SUBMISSION_FIELDS.md`
- `evidence/PACKAGE_RECEIPT.md`

This remains a private audit branch and is not intended for upstream merging.
