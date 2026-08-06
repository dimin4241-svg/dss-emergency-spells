# Triage objection matrix

This matrix separates confirmed behavior from severity interpretation. It is intentionally skeptical: where an objection is partly correct, that part is acknowledged before the narrower security claim is stated.

## 1. “IlkRegistry is intentionally publicly modifiable”

### Accurate part

Yes. Permissionless addition is an explicit design choice, and official tests use `removeAuth -> add` for technical refreshes.

### Response

The finding does not claim all public additions are invalid. It proves that the contract represents temporary refresh and terminal governance offboarding with the same indistinguishable missing-record state.

The official proposal used removal to finalize offboarding. One unprivileged call then executes the real approved spell and returns with 31 of the records restored.

## 2. “Official tests explicitly allow removeAuth followed by add”

That proves the temporary refresh use case. It does not prove that a final offboarding action may be reversed by any address.

A lifecycle tombstone preserves temporary refresh while making terminal removal representable.

## 3. “This was only a badly composed historical spell”

The historical spell supplies a real approved baseline, but the vulnerable primitive remains in the current production deployment.

At block `25,694,337`, one public call—without a historical spell—restores 31 ilks, recaches 26 retired paths in deployed OmegaPoker, and changes 15 `MCD_VAT.spot` values.

## 4. “The report is a feature request for a tombstone”

The requested property is not newly invented. Governance explicitly described the operation as finalizing offboarding and coordinated it with removal of the same legacy oracle paths from Chainlog.

The tombstone is one remediation. The vulnerability is the demonstrated reversal and cross-control bypass.

## 5. “The governance proposal only performed housekeeping”

“Housekeeping” describes the authorization category, not a license for any user to reverse the action. The proposal explicitly stated that the ilks would be removed to finalize offboarding and that legacy oracles would be removed from Chainlog.

The PoC shows both actions complete, yet a public helper reconstructs the removed Registry paths and makes deployed consumers use them again.

## 6. “A malicious governance spell is required”

No. The strongest historical PoC invokes the real approved spell unchanged. The attacker adds no malicious code to the governance proposal.

After the delay, `cast()` is public. The remaining calls—`IlkRegistry.add`, `OmegaPoker.refresh`, and `OmegaPoker.poke`—are also public.

## 7. “A privileged address is required”

No attacker privilege is used in either primary PoC.

The historical one-call proof uses only public functions. The current one-call proof does not invoke governance at all.

Privileged state modeling is used only in the emergency-spell consequence tests to represent the legitimate defender precondition that a deployed emergency spell has been selected as Chief hat. The attacker-controlled step begins after clean emergency completion and consists only of permissionless `add()` calls.

## 8. “Chainlog is still clean, so oracle retirement succeeded”

The Chainlog keys remain absent in the attacked state; this is asserted.

That is precisely the cross-control failure: `IlkRegistry.add()` obtains `pip` from residual `MCD_SPOT`, not Chainlog. OmegaPoker then trusts Registry rather than Chainlog and recaches the retired paths.

The attacker bypasses the retirement effect without restoring or modifying Chainlog.

## 9. “Removing a key from Chainlog was never intended to delete Spotter state”

The report does not claim Chainlog removal should delete Spotter storage. It shows that governance relied on the combination of Chainlog retirement and Registry removal to remove the path from live discovery/automation.

Because Registry removal is permissionlessly reversible, residual Spotter state becomes an alternate reconstruction source that defeats that coordinated outcome.

## 10. “Spotter.poke is public, so changing Vat.spot is not unauthorized”

Correct: the report does not claim an access-control bypass in `Spotter.poke`.

The `MCD_VAT.spot` deltas prove that the reconstructed Registry state is consumed by deployed protocol automation and is not merely a UI/display change. The selected severity remains governance-result deviation, not unauthorized Spotter access.

## 11. “OmegaPoker is only a backup contract”

That limits the operational prevalence but does not falsify the result. OmegaPoker is deployed on mainnet, reads the production Registry, and its public functions deterministically propagate restored records into OSM/Spotter calls.

The report uses OmegaPoker as a real downstream reproducer, not as evidence that it is always the primary production keeper.

## 12. “The affected ilks have zero debt ceilings”

Yes. All 31 positively restored ilks have `line == 0`, and this is disclosed.

The report does not claim borrowing, liquidation, insolvency, or fund loss. The selected impact is the direct deviation from a voted terminal cleanup and reactivation of retired configuration paths.

## 13. “Changing Vat.spot is harmless when line is zero”

The report does not claim immediate financial harm from those deltas. The spot changes establish real on-chain propagation into an explicitly scoped core contract.

The governance deviation is independently proven by the clean `72 -> 30` result versus attacker-controlled `72 -> 30 -> 61` result with `spell.done() == true`.

## 14. “The restored records can simply be removed again”

Not by an unprivileged caller. All 31 Join adapters remain live, while public `remove()` requires a caged Join.

A test attempts all 31 removals; all are blocked. A new privileged governance action is required.

## 15. “Governance can cage the Join”

Caging does not create a terminal block because `add()` does not check `Join.live()`.

A fork test proves:

```text
cage -> add -> remove -> add
```

## 16. “Governance can deny the Join in Vat”

`Vat.deny(join)` blocks Registry addition, but the same authorization is required by `GemJoin.exit()` through `Vat.slip`.

The fork test proves `exit()` reverts after denial. The AAVE Join held approximately `77.033778 AAVE` at the pinned block, so blanket denial is not a universally safe zero-balance cleanup.

## 17. “There is no theft or debt reopening”

Agreed. The report does not select theft, insolvency, permanent freezing, or debt reopening.

Its selected Critical category is the program's governance-result deviation impact.

## 18. “The residual-Art RWA records make this more severe”

They do not. `RWA012-A` and `RWA013-A` have residual `Art == 1`, but actual production `add()` rejects both with `IlkRegistry/invalid-auction-contract`.

They are negative controls and are excluded from the impact claim.

## 19. “DC-IAM could reopen the zero debt ceilings”

It cannot in the tested current state. All 31 removed ilks have zero residual AutoLine configuration and are disabled in LineMom.

Automatic debt-ceiling reopening is not claimed.

## 20. “Legacy Clipper auctions could expose funds”

Not at the pinned block. The 31 restored Clipper entries have zero active auctions and zero internal `Vat.gem` balance at the Clipper addresses.

Auction-fund impact is not claimed.

## 21. “The emergency-spell result requires governance privilege”

The attacker does not obtain or impersonate governance privilege.

The test first establishes a legitimate defender state: the deployed emergency spell is selected as Chief hat and reaches `done == true`. Only then does an unprivileged caller re-add legacy records. Those additions alone create 25 new OSM obligations or 30 new Clipper obligations and flip `done()` back to false.

This is a consequence of the root bug under a legitimate emergency deployment condition, not the primary exploit prerequisite.

## 22. “Emergency done() becoming false is expected when a new ilk is onboarded”

For a genuinely new governance-approved collateral, yes. The tested entries are not new onboardings. They are records governance removed to finalize offboarding, and the corresponding legacy oracle keys remain removed from Chainlog.

The state machine cannot distinguish these retired paths from legitimate new additions, which is the root lifecycle failure.

## 23. “The emergency effect is only one extra transaction”

Mass restoration causes one additional response, but staged restoration is stronger.

By adding adapters one at a time after each defender response, the attacker forces:

```text
25 repeated MultiOsmStop executions
30 repeated MultiClipBreaker executions
```

The measured total repeated response gas is `12,279,717` and `26,663,517`, respectively.

This is disclosed as incident-response grief, not block-gas DoS or theft of gas.

## 24. “This is only gas grief”

No. Gas grief is secondary and bounded.

The primary evidence is:

- real approved governance result `72 -> 30`;
- attacker-controlled final result `72 -> 30 -> 61`;
- Chainlog retirement remains in place;
- 7 selected retired paths are recached in the same call;
- 2 selected `MCD_VAT.spot` values change in that same call;
- the current deployment independently supports `35 -> 66`, 26 recached paths, and 15 Vat deltas.

## 25. “IlkRegistry may not be a separately listed asset”

This is no longer the only scope anchor.

The root cause is in IlkRegistry, but the strongest PoCs reach explicitly listed `MCD_SPOT`, OSM paths, and `MCD_VAT`. The submission should select the closest listed core asset—preferably `MCD_VAT`—and explain the cross-contract causal chain.

The program's resources also direct researchers to Sky ecosystem repositories and current Chainlog deployments.

## 26. “The old vote cannot be manipulated after execution”

The historical PoC demonstrates that the same transaction executing the approved result can return with that result already reversed. It is not a later unrelated state change:

```text
cast approved spell
-> re-add removed records
-> recache retired oracle paths
-> update Vat metadata
-> return to caller
```

`spell.done()` is true throughout the final attacked state.

The current-state PoC separately establishes that the voted terminal state remains unenforced today.

## 27. “Current exploitation requires the old spell”

No. At block `25,694,337`, one public call with no governance action performs:

```text
Registry 35 -> 66
Omega retired cache +26
MCD_VAT.spot changes +15
```

## 28. “Public RPC instability makes the PoC unreliable”

All proofs use pinned blocks and deterministic assertions. The CI workflows use sequential RPC failover and preserve successful machine logs.

Standard `forge build` succeeds without `--via-ir` or special compiler settings.

## 29. “Mainnet testing violated program rules”

All state-changing tests ran on local Ethereum forks. No state-changing public-network transaction was sent.

## 30. “The package contains contradictory exploratory theories”

The final package must exclude:

- the falsified historical `remove -> removeAuth` race;
- the flawed shell addability scan;
- claims of residual debt restoration;
- claims of active legacy auctions;
- claims of residual AutoLine reopening; and
- claims of block-gas DoS.

The negative evidence is retained only in the validation summary and counterevidence logs.

## Recommended submission framing

Do not ask triage to accept the broad proposition that public Registry mutation is always forbidden.

Ask the narrower evidence-backed question:

> Can one unprivileged external call execute the real approved oracle/offboarding spell, leave the selected legacy oracle keys retired in Chainlog, permissionlessly reconstruct 31 removed Registry entries through residual Spotter state, make a deployed Registry consumer recache retired paths, and change MCD_VAT metadata before returning while spell.done() is true?

The mainnet-fork PoC answers yes.

Then add the independent current proof:

> Can the same public primitive, without any historical spell or privilege, currently restore 31 retired records, recache 26 paths, and change 15 MCD_VAT.spot values in one call?

The current pinned fork also answers yes.
