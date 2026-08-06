# Final validation assessment — post red-team

## Disposition

**Technically validated lifecycle weakness; low-confidence bounty report under current Sky rules.**

The behavior is real and current. The principal uncertainty is not exploitability but whether the only surviving effect qualifies as Sky's listed Critical governance-result impact.

## Confidence

- Production `add()` behavior and 31 current restorable records: **very high**
- Atomic real-spell `72 -> 30 -> 61` reproduction: **very high**
- Repeatable public veto after governance `removeAuth`: **very high**
- Inability of public callers to remove restored live entries: **very high**
- Classification as a genuine lifecycle/state-machine weakness: **high**
- Acceptance as the listed Critical governance impact: **low**
- Reliable Medium/Low fallback under the visible impact list: **none**

## Decisive surviving proof tuple

- **Attacker:** arbitrary address.
- **Public entrypoint:** `IlkRegistry.add(address)`.
- **Governance operation being vetoed:** `removeAuth(bytes32)` used to remove named offboarded ilks.
- **Failed state invariant:** the Registry cannot represent terminal absence; the same missing state also means temporary refresh.
- **Historical result:** clean `72 -> 30`; public atomic final state `61`.
- **Current result:** 31/31 adapters remain addable at block `25,694,337`.
- **Repeated result:** three legitimate governance removals followed by four public re-additions; attacker controls final Registry/Omega membership for `758,204` total add gas.
- **Persistence:** restored Joins remain live and Vat-authorized; public removal is blocked.

## Red-team findings that narrow severity

1. Direct public legacy-oracle `poke()` plus public `MCD_SPOT.poke()` produces the same tested `MCD_VAT.spot` result as Registry/Omega. Vat is not a unique causal sink.
2. Sky rules expressly treat inconsistent Chainlog values as non-issues.
3. Sky rules assume necessary grouping of governance and permissionless actions is implemented at spell or `dss-exec-lib` level.
4. All positively restored ilks have zero Art and line.
5. No residual AutoLine, active auctions, funds freeze, theft, insolvency, or permanent DoS exists.
6. Emergency target-set changes are finite operational effects without an independent visible listed impact.

## Likely triage outcomes

Estimated ranges, not guarantees:

- Technical behavior accepted as reproducible: **95–99%**
- Lifecycle/correctness weakness acknowledged: **65–85%**
- Accepted under Critical governance wording: **8–20%**
- Any bounty: **10–25%**
- Rejected as intended public Registry behavior, spell-composition issue, feature request, or non-listed impact: **70–85%**

## Recommendation

Do not submit the old MCD_VAT/Chainlog v3 framing.

A submission is defensible only as a narrow governance-removal-veto report. It should be sent with realistic expectations and no fallback financial or operational impact claims.

The strongest rejection language should be anticipated explicitly:

> The vote and spell executed correctly; the public add is documented behavior, and current Sky rules assign governance/permissionless composition to the spell layer.

The strongest response is:

> The current deployed Registry exposes no terminal removal operation, and a production-fork test proves an arbitrary address can repeatedly veto the exact named Registry absence postcondition after every governance `removeAuth`, including atomically during the real approved spell.
