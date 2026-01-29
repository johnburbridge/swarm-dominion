---
description: Execute an implementation plan step by step. Use after design-from-spec to build the feature according to the plan.
disable-model-invocation: true
---

# Implement Design

Execute an implementation plan, following each step and verifying as you go.

## When to Use

- After `design-from-spec` has produced an approved plan
- Plan exists in `.claude/plans/`
- Ready to write code

## Prerequisites

- Plan file exists: `.claude/plans/[issue-id]-*.md`
- Plan has been reviewed/approved
- You're on the correct git branch

## Process

### 1. Setup

```
Which plan are we implementing?
- Provide the plan file path, OR
- Provide the issue ID (e.g., SPI-1234)
```

Verify git state:
```bash
git branch --show-current
git status
```

### 2. Read the Plan

Load the plan and create a checklist of steps:

```markdown
## Implementation Progress

- [ ] Step 1: [Description]
- [ ] Step 2: [Description]
- [ ] Step 3: [Description]
...
```

### 3. Execute Steps

For each step:

#### a) Announce
State which step you're starting.

#### b) Implement
Write the code following:
- The plan's specifications
- `godot-patterns` skill conventions
- Existing codebase patterns

#### c) Verify
After each step:
- Code compiles (no syntax errors)
- Follows naming conventions
- Type hints present

#### d) Commit (optional)
For larger features, commit after logical groups of steps:
```bash
git add [files]
git commit -m "feat: [description] (WIP: [issue-id])"
```

### 4. Run Verification

After all steps complete:

```bash
# Check formatting
gdformat --check scripts/

# Run linter
gdlint scripts/

# Run tests (if applicable)
godot --headless -s addons/gut/gut_cmdln.gd

# Manual verification
godot --path . scenes/main/main.tscn
```

### 5. Final Review

Use the **reviewer** agent to check:
- All plan steps completed
- All acceptance criteria satisfied
- Conventions followed
- No obvious issues

### 6. Commit and Update

```bash
# Stage all changes
git add [specific files]

# Commit with issue reference
git commit -m "feat: [feature description] ([issue-id])

[Brief summary of what was implemented]

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

Update Linear issue status to "In Review" or "Done".

## Handling Issues

### Plan doesn't match reality
If you discover the plan needs adjustment:
1. Document what's different
2. Propose the change
3. Get approval before proceeding
4. Update the plan file

### Step fails
If a step can't be completed as written:
1. Stop implementation
2. Document the blocker
3. Either: fix the plan, or escalate to user

### Unexpected complexity
If a step is much larger than expected:
1. Break it into sub-steps
2. Document the breakdown
3. Continue with smaller increments

## Output

- Modified/created files as specified in plan
- Git commit(s) with issue references
- Updated Linear issue status

## Definition of Done

- [ ] All plan steps executed
- [ ] Verification commands pass
- [ ] Reviewer agent approves (or issues addressed)
- [ ] Changes committed
- [ ] Linear updated
