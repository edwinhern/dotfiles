---
description: "React-specific component and UI implementation guidelines."
applyTo: "**/*.tsx"
---

# 03. React Guidelines

Follow 00-meta-rules, 01-coding-standards, and 02-typescript-guidelines.

## Components

- Use functional components only.
- Keep components small, focused, and composable.
- Use clear, consistent component and file naming.

## Hooks

- Follow the Rules of Hooks (no conditional or looped hooks).
- Prefer custom hooks for reusable stateful logic.

## Styling

- Use CSS Modules for component styling.
- Keep styling co-located with components when practical.

## Accessibility

- Ensure keyboard operability for interactive elements.
- Provide appropriate ARIA attributes and labels.
- Use proper roles and focus management for custom controls.

## Composition Patterns

- Favor composition over inheritance.
- Separate data-fetching from presentation when it improves clarity.
