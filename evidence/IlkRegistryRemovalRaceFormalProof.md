# Formal proof: permissionless `remove` changes the result of an authorized `removeAuth` batch

## Definitions

Let:

- `A` be the IlkRegistry `ilks` array immediately before the August 7, 2025 executive spell is cast.
- `S` be the set of ilks represented by `A`.
- `n = |A|`.
- `T` be the 42 unique ilks passed to `removeAuth` by the real spell (`LSE-MKR-A` plus the 41 offboarded ilks).
- `t0 = AAVE-A`, where `t0 ∈ T`.

The official spell test establishes that every element of `T` is present before execution and that clean execution reduces `count()` by exactly 42.

## Registry behavior

For a registered caged class-1/class-2 ilk, anyone may call:

```solidity
remove(ilk)
```

This invokes `_remove(ilk)` and deletes both the array entry and `ilkData[ilk]`.

The authorized function:

```solidity
removeAuth(ilk)
```

also invokes `_remove(ilk)`, but performs no existence or consistency check.

For a missing key `x`, Solidity returns the zero-initialized mapping value, so:

```solidity
ilkData[x].pos == 0
```

`_remove(x)` therefore replaces `ilks[0]` with the final array element, pops once, updates only the moved element's position, and executes `delete ilkData[x]`. It does not delete the mapping of the element actually evicted from enumeration.

## Clean execution

Because all 42 elements of `T` exist and the official test confirms the expected outcome:

```text
|A_clean| = n - 42
S_clean = S \ T
```

## Attacked execution

Before `cast()`, an unprivileged attacker calls:

```solidity
remove(t0)
```

The array length becomes `n - 1` and `ilkData[t0]` is deleted.

The approved spell then executes the same 42 `removeAuth` calls. Each call invokes `_remove` and unconditionally performs exactly one `pop()`. In particular, `removeAuth(t0)` still performs a pop even though `t0` is already absent.

Therefore:

```text
|A_attack| = (n - 1) - 42 = n - 43
```

and:

```text
|A_attack| = |A_clean| - 1
```

## Unintended victim must exist

After the spell, every target mapping in `T` has been deleted by its corresponding `removeAuth` call. A target is either removed normally or was already displaced by an earlier missing-key removal; in neither case can it remain a valid enumerated registry member.

The attacked final array contains one fewer element than `S \ T`. Consequently, by cardinality, there exists at least one:

```text
v ∈ S \ T
```

such that:

```text
v ∈ S_clean
v ∉ S_attack
```

Thus the approved spell necessarily removes at least one ilk that was not part of the voted removal set.

## Ghost mapping must exist

`_remove` deletes only `ilkData[argument]`, not `ilkData[actual array element evicted]`.

The unintended victim `v` is not in `T`, so none of the 42 spell calls executes:

```solidity
delete ilkData[v]
```

Therefore the final attacked state necessarily contains:

```text
ilkData[v].join != address(0)
v not in list()
get(pos(v)) != v
```

This is a deterministic array/mapping consistency violation, independent of array order and independent of which concrete non-target ilk becomes `v`.

## Atomic exploitability

After the GSM delay, `DssExec.cast()` is public. The attacker can execute both state transitions in one transaction:

```solidity
registry.remove(t0);
spell.cast();
```

No privileged key, malicious governance proposal, miner cooperation, or probabilistic front-running is required.

If the spell reverted, the entire transaction would revert. The vulnerable missing-key removal does not revert, so the legitimate spell can finish with `done == true` while producing a state different from the voted outcome.

## Security impact

The official proposal authorized removal of exactly the listed offboarded ilks. The attacked execution removes those targets plus at least one non-target and leaves the non-target's metadata as a ghost mapping.

This is an execution-layer deviation from the approved governance result, not a temporary vote-display issue. Contracts that enumerate `list()` no longer see the unintended victim even though its mapping and core Vat state can remain present.

## Required fix

Protect the shared internal removal path:

```solidity
function _remove(bytes32 ilk) internal {
    Ilk storage data = ilkData[ilk];
    require(data.join != address(0), "IlkRegistry/invalid-ilk");

    uint256 index = data.pos;
    require(index < ilks.length && ilks[index] == ilk, "IlkRegistry/inconsistent-ilk");

    bytes32 movedIlk = ilks[ilks.length - 1];
    ilks[index] = movedIlk;
    ilkData[movedIlk].pos = uint96(index);
    ilks.pop();
    delete ilkData[ilk];
}
```

The check must be inside `_remove`, not only in `remove`, because `removeAuth` is the vulnerable sink.
