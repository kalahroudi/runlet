# How we build RunLet: spec-driven, one spec per PR

Every change starts as a short written spec. The spec is approved first, then built. One spec becomes exactly one pull request.

## Rules

1. **One spec, one PR.** If a spec needs more than one PR, split the spec.
2. **Small.** Target under about 500 changed lines, excluding generated files and lockfiles. A reviewer should finish it in one sitting.
3. **Spec before code.** The spec file is the first commit of the PR branch (or its own tiny PR for risky specs). Code that disagrees with the spec is a bug in one of them; fix whichever is wrong in the same PR.
4. **Every acceptance criterion is checkable.** Each one maps to a test, or to a manual step listed in the spec.
5. **No hidden scope.** Anything not in the spec goes in "Non-goals" or a new spec.
6. **Order matters.** A spec lists the specs it depends on. Build in the order of [ROADMAP.md](ROADMAP.md).

## Lifecycle

`Draft` → `Approved` (by the product owner) → `In progress` (branch open) → `Done` (PR merged, status updated in the same PR).

## Branch and PR naming

- Branch: `spec/NNN-short-name`
- PR title: `Spec NNN: Short name`
- PR body: link to the spec, then tick each acceptance criterion with how it was verified.

## Template

Copy [_template.md](_template.md).

## Reference

The approved visual mock lives in [../mock/runlet.html](../mock/runlet.html). It is a scripted prototype, not a source of truth for behavior. The specs are.
