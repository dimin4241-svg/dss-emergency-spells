# Current Sky bug-bounty rules relevant to this report

Checked against the official Immunefi Sky program on 2026-08-06.

## Program state

- Last updated: 2026-07-21.
- Primacy of Rules.
- Proof of concept required.
- Current Critical smart-contract minimum: USD 150,000.
- The program says a Critical impact on any deployed smart contract in the Sky codebase may be submitted for consideration.

## Selected impact

The only plausible listed impact for this report is:

```text
Manipulation of governance voting result deviating from voted outcome and resulting in a direct change from intended effect of original results
```

No reliable Medium or Low fallback impact is visible for a pure Registry lifecycle/configuration veto.

## Governance assumptions that materially weaken the report

The program states, in substance:

1. privileged wards and governance roles are trusted;
2. when governance actions must be grouped with permissionless actions, that grouping is assumed to be implemented at the spell or `dss-exec-lib` layer;
3. Chainlog can be maintained after components are added or removed, so inconsistent Chainlog values are assumed non-issues;
4. only listed impacts are accepted.

## Consequence for this submission

The report must not use Chainlog inconsistency, direct oracle/Spotter effects, generic gas grief, or configuration drift as independent impacts.

The surviving report theory is limited to whether a repeatable public veto over the exact Registry absence postcondition approved by governance qualifies as the listed Critical governance-result impact.

Official program references:

- `https://immunefi.com/bug-bounty/sky/information/`
- `https://immunefi.com/bug-bounty/sky/scope/`
- `https://immunefi.com/bug-bounty/sky/resources/`
