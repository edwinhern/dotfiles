---
description: "Language-agnostic engineering standards for maintainable code."
applyTo: "**/*.ts,**/*.tsx"
---

# 01. Coding Standards

These standards apply in all modes. For behavioral expectations, see 00-meta-rules.

## Readability and Maintainability

- Prioritize clarity and simplicity over cleverness.
- Keep code DRY without sacrificing readability.
- Favor small, focused functions and files.
- Use early returns whenever possible to make the code more readable.

## Naming Conventions

- Use descriptive, intention-revealing names.
- Match existing repository naming patterns.

## Immutability Preference

- Prefer immutable data patterns.
- Avoid in-place mutations unless necessary and justified.

## Async and Error Handling

- Prefer async/await over promise chains.
- Always handle errors intentionally.

## File Hygiene

- Remove unused code, dead files, and debugging artifacts.
- Keep file scope aligned to a single responsibility.

## Scope Guardrails

- Do not include company-specific content here.
- This standard applies equally in all modes.
