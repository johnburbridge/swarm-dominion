---
description: Spec-driven development workflow for Swarm Dominion. Use when you want a structured approach to feature development with specifications, plans, and reviews.
disable-model-invocation: true
---

# Spec-Driven Workflow

A structured workflow for feature development that separates concerns into distinct phases.

## Overview

```
┌─────────────┐    ┌─────────────────┐    ┌──────────────────┐
│ write-spec  │ →  │ design-from-spec│ →  │ implement-design │
│             │    │                 │    │                  │
│ Requirements│    │ Implementation  │    │ Code + Verify    │
│ & Criteria  │    │ Plan            │    │                  │
└─────────────┘    └─────────────────┘    └──────────────────┘
```

## When to Use This Workflow

- Complex features with unclear requirements
- Features that benefit from upfront design
- Work that will be reviewed by others
- Learning/documenting as you build

## When NOT to Use

- Simple bug fixes
- Small, well-defined changes
- Urgent hotfixes
- Exploratory/prototype work

## The Three Skills

### 1. write-spec
**Input:** Linear issue or user story
**Output:** `.claude/specs/[issue-id]-[name].md`

Clarifies requirements, defines acceptance criteria, identifies scope.

### 2. design-from-spec
**Input:** Approved specification
**Output:** `.claude/plans/[issue-id]-[name].md`

Creates step-by-step implementation plan with file changes and test plan.

### 3. implement-design
**Input:** Approved plan
**Output:** Working code, commits, Linear updates

Executes plan systematically with verification at each step.

## Supporting Agents

The workflow uses these specialized agents:

| Agent | Used In | Purpose |
|-------|---------|---------|
| context-engineer | write-spec, design-from-spec | Research codebase |
| planner | design-from-spec | Create implementation plans |
| reviewer | implement-design | Verify implementation |

## Quick Start

Invoke any skill directly:
- `/write-spec` - Start from requirements
- `/design-from-spec` - Start from existing spec
- `/implement-design` - Start from existing plan

Or use the full workflow sequentially for maximum structure.

## Artifacts

```
.claude/
├── specs/           # Feature specifications
│   └── spi-1234-unit-selection.md
└── plans/           # Implementation plans
    └── spi-1234-unit-selection.md
```
