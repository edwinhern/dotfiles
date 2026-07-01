---
name: typescript
description: "TypeScript implementation standards: strict typing, immutability, and idiomatic patterns. Use when writing, reviewing, or refactoring TypeScript (.ts/.tsx) code."
---

# TypeScript

Standards for writing maintainable TypeScript. Apply alongside general engineering
principles: clarity over cleverness, small focused functions and files, early
returns, descriptive names, and intentional error handling.

## Type safety

- Use strict typing. Avoid `any` and `unknown`.
- Prefer explicit types for public APIs and module boundaries.
- Use type inference where it improves readability without ambiguity.

## Types and interfaces

- Use interfaces or type aliases as appropriate.
- Keep types small and composable.

## Immutability and optionality

- Prefer `readonly` data where possible.
- Avoid in-place mutation; use object and array spread to build new values.
- Use optional chaining and nullish coalescing where they clarify intent.

## Declarations

- Use `const` by default and `let` only when reassignment is required.
- Never use `var`.

## Functions

- Use function declarations for named, exported functions.
- Use arrow functions for callbacks and inline logic.

## Objects and arrays

- Prefer `map`, `filter`, and `reduce` over imperative loops.
- Handle errors intentionally; prefer `async`/`await` over promise chains.
