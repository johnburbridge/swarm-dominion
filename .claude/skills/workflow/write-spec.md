---
description: Write a feature specification from a Linear issue or user story. Use when starting a new feature to clarify requirements before planning.
disable-model-invocation: true
---

# Write Spec

Transform a Linear issue or user story into a detailed feature specification.

## When to Use

- Starting work on a new feature
- Linear issue lacks detail for implementation
- Requirements need clarification before planning

## Process

### 1. Gather Source Information

Read the Linear issue or get requirements from the user:

```
What feature are we specifying? Provide:
- Linear issue ID (e.g., SPI-1234), OR
- User story in "As a... I want... So that..." format
```

### 2. Research Context

Use the **context-engineer** agent to gather:
- Related existing code
- Similar patterns in the codebase
- Dependencies and interactions

### 3. Write the Specification

Create `.claude/specs/[issue-id]-[feature-name].md`:

```markdown
# Spec: [Issue ID] - [Feature Name]

**Linear Issue:** [Link]
**Status:** Draft | Review | Approved
**Author:** [Name]
**Date:** [YYYY-MM-DD]

## Overview

One paragraph describing what this feature does and why.

## User Story

As a [role], I want [feature], so that [benefit].

## Acceptance Criteria

Measurable, testable criteria. Use Given/When/Then for complex behaviors:

1. **[Criterion name]**
   - Given [precondition]
   - When [action]
   - Then [expected result]

2. **[Criterion name]**
   - [Simple criterion if GWT is overkill]

## Scope

### In Scope
- What this feature WILL do

### Out of Scope
- What this feature will NOT do (defer to future work)

## Dependencies

- Systems this feature interacts with
- Prerequisites that must exist

## Technical Considerations

- Performance requirements
- Edge cases to handle
- Known constraints

## Open Questions

- [ ] Question that needs answering before implementation
- [ ] Another question

## References

- Related Linear issues
- Relevant documentation
- Similar implementations
```

### 4. Review Checklist

Before marking complete:

- [ ] All acceptance criteria are testable
- [ ] Scope is clear (in/out)
- [ ] Dependencies identified
- [ ] Open questions documented (or resolved)
- [ ] Stakeholder review if needed

## Output

Save spec to: `.claude/specs/[issue-id]-[feature-name].md`

Example: `.claude/specs/spi-1234-unit-selection.md`
