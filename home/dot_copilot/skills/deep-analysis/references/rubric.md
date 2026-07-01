<!-- Source: IMG_2694 — angled photo, transcription is best-effort. -->

# JIRA Deep Analysis Rubric

## Purpose

Measure analysis completeness on JIRA tickets across the dimensions: business goals, requirements, dependencies, edge cases, and cross-functional questions. Use this rubric to score the research before producing a Research Summary.

## Scoring Categories

### 1. Requirements Understanding (40 points)

| Criterion                   | Points | Self-Check Question                                     |
| --------------------------- | ------ | ------------------------------------------------------- |
| Core requirement understood | 10     | "Can I explain what needs to be built in one sentence?" |
| Acceptance criteria clear   | 10     | "Do I know exactly when to say 'done'?"                 |
| Constraints documented      | 10     | "Have I captured limits, perf, and a11y constraints?"   |
| Edge cases identified       | 10     | "What could go wrong? What are the boundaries?"         |

### 2. Technical Clarity (30 points)

| Criterion                       | Points | Self-Check Question                                     |
| ------------------------------- | ------ | ------------------------------------------------------- |
| Affected files identified       | 10     | "Do I know which files to touch?"                       |
| Implementation approach defined | 10     | "Could I describe the change in 3-5 bullets?"           |
| Dependencies enumerated         | 5      | "What internal/external APIs or services are involved?" |
| Data sources understood         | 5      | "Where does the data come from? How is it shaped?"      |

### 3. Context Completeness (30 points)

| Criterion               | Points | Self-Check Question                                    |
| ----------------------- | ------ | ------------------------------------------------------ |
| Design context (Figma)  | 10     | "Do I have design specs (or know we don't need them)?" |
| Related issues mapped   | 10     | "Are there related tickets, PRs, or prior work?"       |
| Stakeholders identified | 5      | "Who owns this? Who reviews this?"                     |
| Documentation reviewed  | 5      | "Have I read the relevant Confluence pages?"           |

## Confidence Calculation

```
confidence = (documented_points / 100) * 100
```

### Recommendation

- confidence ≥ 80% — ready to hand off to Plan Agent
- confidence < 80% — list specific questions for Planning / Needs Clarification
