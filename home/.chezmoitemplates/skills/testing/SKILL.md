---
name: testing
description: "Testing standards for Jest and React Testing Library: accessibility-first queries, behavior over implementation, and meaningful coverage. Use when writing or reviewing tests (.test.ts/.test.tsx)."
---

# Testing

Standards for component and unit tests with Jest and React Testing Library.

## Tooling

- Use Jest with React Testing Library (`@testing-library/react`).
- Test loaders and actions for data correctness.
- Mock fetch requests and responses where applicable.

## Query priority (accessibility-first)

Prefer queries in this order:

1. Accessible to everyone: `getByRole`, `getByLabelText`, `getByPlaceholderText`, `getByText`, `getByDisplayValue`
2. Semantic: `getByAltText`, `getByTitle`
3. Test IDs (last resort): `getByTestId`

```typescript
// Good: accessible queries
screen.getByRole("button", { name: /submit/i });
screen.getByLabelText(/email address/i);
screen.getByRole("heading", { level: 1 });

// Avoid: implementation details
screen.getByTestId("submit-button");
container.querySelector(".submit-btn");
```

## What to test

Do test:

- User-visible behavior and interactions
- Accessibility: roles, labels, focus management
- Loading and error states
- Form validation and submission
- Navigation and routing
- Data transformation in loaders and side effects in actions

Do not test:

- Implementation details such as internal state or methods
- Third-party library internals
- Exact CSS class names

## Coverage

- Aim for meaningful coverage, not 100%.
- Focus on critical paths, edge cases (empty, error, loading), and accessibility.

## Mocking

- Mock external boundaries: network, storage, timers.
- Keep mocks minimal and reset them between tests.
- Avoid over-mocking UI primitives.
