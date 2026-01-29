---
description: Create an implementation plan from a feature specification. Use after write-spec to design how the feature will be built.
disable-model-invocation: true
---

# Design from Spec

Transform a feature specification into an actionable implementation plan.

## When to Use

- After `write-spec` has produced an approved specification
- Spec exists in `.claude/specs/`
- Ready to plan implementation details

## Prerequisites

- Specification file exists: `.claude/specs/[issue-id]-*.md`
- Spec status is "Approved" (or you're combining write + design)

## Process

### 1. Read the Specification

```
Which spec are we designing from?
- Provide the spec file path, OR
- Provide the issue ID (e.g., SPI-1234)
```

### 2. Analyze Requirements

From the spec, extract:
- Acceptance criteria → Test scenarios
- Dependencies → Integration points
- Technical considerations → Implementation constraints

### 3. Research Implementation

Use the **context-engineer** agent to find:
- Files that need modification
- Existing patterns to follow
- Similar implementations to reference

### 4. Write the Plan

Use the **planner** agent to create `.claude/plans/[issue-id]-[feature-name].md`:

```markdown
# Plan: [Issue ID] - [Feature Name]

**Spec:** [Link to spec file]
**Linear Issue:** [Link]

## Summary

Brief description of what will be implemented.

## Implementation Steps

### Step 1: [Action verb] [Component]

**File:** `path/to/file.gd`
**Effort:** Small | Medium | Large

What changes and why.

```gdscript
# Key code structure (not full implementation)
func example() -> void:
    pass
```

**Depends on:** None | Step N

### Step 2: [Action verb] [Component]
...

## Files to Modify

| File | Action | Description |
|------|--------|-------------|
| `path/file.gd` | Modify | Add X functionality |
| `path/new.gd` | Create | New component for Y |

## Test Plan

How to verify each acceptance criterion:

| Criterion | Test Method |
|-----------|-------------|
| AC1: Description | Manual: Do X, expect Y |
| AC2: Description | Automated: Run test Z |

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Risk description | High/Med/Low | How to address |

## Definition of Done

- [ ] All acceptance criteria pass
- [ ] Code follows godot-patterns conventions
- [ ] No regressions in existing functionality
- [ ] Changes committed with issue reference
```

### 5. Review Checklist

Before implementation:

- [ ] All spec acceptance criteria have implementation steps
- [ ] Files to modify are identified
- [ ] Dependencies between steps are clear
- [ ] Test plan covers all criteria
- [ ] Risks identified

## Output

Save plan to: `.claude/plans/[issue-id]-[feature-name].md`

Example: `.claude/plans/spi-1234-unit-selection.md`

## Next Step

After plan approval, use `implement-design` to execute the plan.
