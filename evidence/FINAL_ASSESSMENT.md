# Final validation assessment

## Disposition

**Reportable, technically validated, severity interpretation remains program-dependent.**

## Confidence

- Root-cause correctness: **high**
- Current exploitability of 31 permissionless additions: **high**
- Atomic historical governance-result deviation: **high**
- Cross-control propagation through MCD_SPOT/OmegaPoker into MCD_VAT: **high**
- Emergency-spell completion reopening and staged response grief: **high**
- Acceptance under the exact Critical governance-impact wording: **medium**

## Decisive proof tuple

- **Attacker position:** arbitrary unprivileged address.
- **Controlled entrypoints:** public `DssExec.cast`, public `IlkRegistry.add`, public `OmegaPoker.refresh`, public `OmegaPoker.poke`.
- **Failed control:** terminal governance offboarding is represented only by deletion; no lifecycle block survives.
- **Alternate reconstruction source:** residual Spotter and Dog configuration while Chainlog remains retired.
- **Sink:** Registry list consumers and MCD_VAT spot metadata.
- **Observed result:** one call produces Registry count 61 instead of clean 30, leaves eight selected Chainlog keys retired, recaches seven selected retired paths, changes two selected MCD_VAT spot values, and returns with the approved spell marked done.

## Remaining triage risk

The main residual risk is semantic rather than technical: triage may interpret the listed governance-manipulation impact narrowly as manipulation of vote counting rather than manipulation of the execution result of a passed vote.

The report addresses this by proving that the deviation occurs inside the same transaction that executes the real approved spell, not through a later malicious governance proposal, and by independently proving that the terminal result remains unenforced in the current deployment.
