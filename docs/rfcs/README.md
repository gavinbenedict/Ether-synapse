# Ether Synapse — Request for Comments (RFC)

> RFC system established: June 2026

---

## Purpose

RFCs (Requests for Comments) are design documents for **proposed features and significant behavioural changes** to Ether Synapse that require community discussion before implementation begins.

An RFC captures the problem being solved, the proposed solution, open questions, and the reasoning behind trade-offs. It is a communication tool, not a binding specification. An accepted RFC represents community agreement on intent and approach — not on every implementation detail.

---

## RFCs vs. Architecture Decision Records (ADRs)

| | RFC | ADR |
|-|-----|-----|
| **Scope** | Proposed future features or changes | Decisions already made |
| **Status at creation** | Draft — not yet decided | Accepted (or deprecated) |
| **Author** | Any contributor | Core maintainers |
| **Audience** | Community — invites feedback | Future contributors — explains rationale |
| **Location** | `docs/rfcs/` | `docs/architecture/decisions/` |
| **Outcome** | Accepted → implemented; Rejected → archived | Stable reference unless superseded |

In short: **ADRs record what was decided and why. RFCs are how we decide what to do next.**

---

## RFC Lifecycle

```
DRAFT → OPEN FOR COMMENT → ACCEPTED → IMPLEMENTED
                        ↘
                         REJECTED → ARCHIVED
```

| Stage | Meaning |
|-------|---------|
| **Draft** | Author is still writing; not yet ready for community review |
| **Open for Comment** | RFC is posted as a pull request to `develop`; community discussion happens in PR comments |
| **Accepted** | Maintainers close the PR with approval; RFC is merged to `docs/rfcs/`; implementation work may begin |
| **Rejected** | Proposal will not be implemented in its current form; RFC is archived with a rejection rationale |
| **Implemented** | Feature is complete and shipped; RFC status updated; may be referenced from a future ADR |

An RFC that is **Accepted** does not guarantee a timeline. It means the approach is agreed upon and the feature is welcome.

---

## Naming Convention

```
NNNN-short-descriptive-title.md

NNNN  — Four-digit sequential number, zero-padded: 0001, 0002, …
title — Lowercase, hyphen-separated, describes the feature, not the solution
```

**Examples:**
- `0001-trusted-devices.md`
- `0002-transfer-resume.md`
- `0003-ios-background-transfers.md`

Numbers are assigned when the RFC moves from Draft to Open for Comment. Draft RFCs should use `0000-your-title.md` until a number is assigned by a maintainer.

---

## RFC Document Template

```markdown
# RFC NNNN — Title

**Status**: Draft | Open for Comment | Accepted | Rejected | Implemented
**Author**: GitHub handle or name
**Date**: YYYY-MM
**Replaces**: (RFC number if superseding an earlier RFC, otherwise omit)

---

## Summary

One paragraph description of the proposed feature.

## Motivation

Why is this feature needed? What problem does it solve? Who benefits?

## Detailed Design

Technical description of the proposed change. Include:
- Protocol changes (if any)
- New Rust modules or modifications to existing ones
- New Flutter features or modifications
- Impact on the bridge API
- Security considerations

## Drawbacks

What are the costs of implementing this? What could go wrong?

## Alternatives Considered

What other approaches were considered and why were they not chosen?

## Open Questions

Unresolved design questions that need community input before this RFC can be accepted.

## Future Work

Related features or improvements that are deliberately out of scope for this RFC.
```

---

## Current RFC Index

| RFC | Title | Status |
|-----|-------|--------|
| *(none yet)* | | |

---

## Planned RFCs

The following topics have been identified as candidates for future RFCs. They are listed here to signal intent, not to pre-approve the proposals.

| Candidate RFC | Description |
|---------------|-------------|
| `0001-trusted-devices` | Persist a cryptographic fingerprint of previously paired devices to allow re-pairing without a full PIN verification ceremony |
| `0002-transfer-resume` | Allow an interrupted file transfer to resume from the last acknowledged chunk without re-pairing |
| `0003-ios-background-transfers` | Enable file reception on iOS when Ether Synapse is in the background, using iOS Background Transfer capabilities |

These are not yet formal RFCs. Authors who wish to propose one of these features should open a Draft RFC pull request against `develop`.

---

## Contributing an RFC

1. Fork the repository and create a branch: `rfc/0000-your-feature-name`.
2. Copy the RFC template above into `docs/rfcs/0000-your-title.md`.
3. Fill in the template. Focus on the problem and motivation before the solution.
4. Open a pull request against `develop` with the title `RFC: Your Feature Title`.
5. Request a maintainer to assign an RFC number.
6. Address feedback in the PR discussion.
7. If accepted, a maintainer will merge the RFC and update the index above.

There is no minimum or maximum length for an RFC. It should be as long as necessary to clearly describe the proposal and invite focused feedback.
