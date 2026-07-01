---
name: react
description: "React component and UI guidelines: functional components, hooks, accessibility, and composition. Use when building or reviewing React (.tsx) components."
---

# React

Guidelines for React UI work. Build on the `typescript` skill for typing and on
general engineering principles for structure and naming.

## Components

- Use functional components only.
- Keep components small, focused, and composable.
- Use clear, consistent component and file naming.

## Hooks

- Follow the Rules of Hooks: no conditional or looped hooks.
- Extract reusable stateful logic into custom hooks.

## Styling

- Use CSS Modules for component styling.
- Co-locate styling with components when practical.

## Accessibility

- Ensure keyboard operability for interactive elements.
- Provide appropriate ARIA attributes and labels.
- Use proper roles and focus management for custom controls.

## Composition

- Favor composition over inheritance.
- Separate data fetching from presentation when it improves clarity.
