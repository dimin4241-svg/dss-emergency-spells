# Canonical v3 package receipt

## Package

`sky-ilk-registry-governance-retirement-validation-v3.zip`

SHA-256:

```text
879f004191d2cc610296462b9fa9a75b02f665dc1ed110894aa49280f5fea842
```

## Package workflow

- repository: `dimin4241-svg/fluid-contracts-public`
- run: `31089526583`
- artifact: `sky-ilk-registry-governance-retirement-validation-v3`
- conclusion: success

## Canonical validation workflow

- run: `31089226913`
- artifact: `sky-canonical-governance-retirement-validation-v3`
- standard Solc build: success
- canonical cases passed: 14
- failed assertions: 0

## Local independent package verification

After downloading the uploaded artifact, the inner ZIP was extracted and its included verifier was run:

```text
VALIDATION PASSED
Hashes, primary evidence markers, source presence, and falsified-artifact exclusions passed.
```

The independently recomputed outer ZIP hash matched `PACKAGE_SHA256.txt`.
