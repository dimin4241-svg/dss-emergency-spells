# Recommended Immunefi submission fields — revised after red-team

## Asset

Primary target:

```text
IlkRegistry
0x5a464C28D19848f44199D003BeF5ecc87d090F87
```

Select IlkRegistry or the closest available “other deployed Sky/Core System contract” option if the submission interface exposes one.

**Do not select MCD_VAT merely to create an in-scope sink.** A differential control proves the tested `Vat.spot` result is reproducible through direct public legacy-oracle and Spotter calls without Registry re-addition.

If the interface has no appropriate asset, explicitly state the exact production contract and rely on the program statement that a Critical impact on any deployed Sky smart contract may be submitted for consideration. Treat this as a material scope risk.

## Impact

```text
Critical — Manipulation of governance voting result deviating from voted outcome and resulting in a direct change from intended effect of original results
```

There is no reliable fallback impact in the currently visible Sky smart-contract impact list.

## Title

```text
Permissionless IlkRegistry add lets any address repeatedly veto governance removal of offboarded ilks
```

## First facts above the fold

1. The official proposal said named offboarded ilks would be removed from IlkRegistry to finalize offboarding.
2. Clean real-spell result is `72 -> 30`.
3. One public transaction executes the real spell and ends at `61`, restoring 31 removed records.
4. At current pinned block `25,694,337`, production `add()` still accepts all 31 adapters.
5. A repeated-veto test proves three legitimate governance `removeAuth` cycles are followed by four public re-additions; the arbitrary caller controls the final Registry and Omega target-set state for `758,204` total add gas.
6. Public callers cannot remove the restored entries because the Joins remain live.

## Mandatory counterevidence disclosure

The internal package should retain, and the report should accurately account for:

- public Registry mutability is documented;
- official tests allow `removeAuth -> add` for refresh;
- Sky rules assume governance/permissionless grouping at spell or `dss-exec-lib` level;
- Chainlog inconsistency is an explicit non-issue;
- direct public oracle + Spotter calls reproduce the tested `MCD_VAT.spot` result;
- all 31 addable ilks have zero Art and zero line;
- no active auctions, residual AutoLine, fund freeze, theft, insolvency, or block-gas DoS exists.

## Do not select or claim

- MCD_VAT as a causal asset;
- Chainlog bypass as an impact;
- theft;
- insolvency;
- permanent or temporary freezing;
- debt reopening;
- active-auction loss;
- residual AutoLine reopening;
- emergency DoS;
- malicious governance proposal; or
- privileged attacker access.
