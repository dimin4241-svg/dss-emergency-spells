# Recommended Immunefi submission fields

## Asset

Primary selection: **MCD_VAT**

Explain in the first paragraph that the root cause is in production IlkRegistry, while the strongest atomic PoCs propagate the reconstructed retired paths through MCD_SPOT/OSM into the explicitly listed MCD_VAT asset.

## Impact

**Critical — Manipulation of governance voting result deviating from voted outcome and resulting in a direct change from intended effect of original results**

## Title

**Permissionless IlkRegistry add atomically defeats coordinated governance oracle retirement and reactivates retired paths in MCD_VAT**

## PoC attachment

`sky-ilk-registry-governance-retirement-validation-v3.zip`

SHA-256:

```text
879f004191d2cc610296462b9fa9a75b02f665dc1ed110894aa49280f5fea842
```

## First five facts to place above the fold

1. Real approved spell and exact pre-cast block are used.
2. Clean result is `72 -> 30`; attacker-controlled one-call result is `72 -> 30 -> 61`, with `spell.done() == true`.
3. Eight selected legacy oracle keys remain absent from Chainlog.
4. In the same unprivileged call, seven retired paths are recached and two MCD_VAT spot values change.
5. The same current-state primitive independently restores 31 records, recaches 26 paths, and changes 15 MCD_VAT spot values without invoking governance.

## Do not select or claim

- theft;
- insolvency;
- permanent freezing;
- debt reopening;
- active-auction loss;
- block-gas denial of service;
- malicious governance proposal;
- privileged attacker access.
