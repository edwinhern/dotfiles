---
description: "TypeScript-specific implementation rules."
applyTo: "**/*.ts,**/*.tsx"
---

# 02. TypeScript Guidelines

Follow 00-meta-rules and 01-coding-standards for general behavior and quality.

## Type Safety

- Use strict typing and do not use `any` or `unknown`.
- Prefer explicit types for public APIs and boundaries.
- Use type inference where it improves readability without ambiguity.

## Types and Interfaces

- Use interfaces or type aliases appropriately.
- Keep types small and composable.

## Immutability and Optionality

- Prefer readonly data where possible.
- Use optional chaining and nullish coalescing appropriately.

## Declarations

- Use `const` by default and `let` only when reassignment is required.
- Never use `var`.

## Functions

- Use function declarations for named, exported functions.
- Use arrow functions for callbacks and inline logic.

## Object and Array Patterns

- Use object/array spread to avoid mutation.
- Prefer array methods like `map`, `filter`, and `reduce`.
