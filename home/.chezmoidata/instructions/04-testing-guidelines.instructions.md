---
description: "Testing standards for Jest and React Testing Library"
applyTo: "**/*.test.ts,**/*.test.tsx"
---

# 04. Testing Guidelines

Follow 00-meta-rules and 01-coding-standards for general expectations.

## Tooling

- Use Jest with React Testing Library.

### Testing

- Use `@testing-library/react` for component testing.
- Write tests for loaders and actions ensuring data correctness.
- Mock fetch requests and responses where applicable.

## Query Priority (Accessibility-First)

Use queries in this order of priority:

1. **Accessible to Everyone:**
   - `getByRole` - Query by ARIA role (preferred for most elements)
   - `getByLabelText` - Query form elements by label
   - `getByPlaceholderText` - Query by placeholder text
   - `getByText` - Query by visible text content
   - `getByDisplayValue` - Query by current input value

2. **Semantic Queries:**
   - `getByAltText` - Query images by alt text
   - `getByTitle` - Query by title attribute

3. **Test IDs (Last Resort):**
   - `getByTestId` - Only when other queries aren't practical

```typescript
// ✅ Good - Uses accessible queries
screen.getByRole("button", { name: /submit/i });
screen.getByLabelText(/email address/i);
screen.getByRole("heading", { level: 1 });
screen.getByRole("textbox", { name: /search/i });

// ❌ Avoid - Implementation details
screen.getByTestId("submit-button");
container.querySelector(".submit-btn");
```

### What to Test

✅ **Do Test:**

- User-visible behavior and interactions
- Accessibility (roles, labels, focus management)
- Loading and error states
- Form validation and submission
- Navigation and routing
- Data transformation in loaders
- Side effects in actions

❌ **Don't Test:**

- Implementation details (state, internal methods)
- Third-party library internals
- Exact CSS class names
- Component internal state

## Coverage Expectations

- Aim for meaningful coverage, not 100%
- Critical paths: loaders, actions, user interactions
- Edge cases: empty states, errors, loading
- Accessibility: keyboard navigation, screen reader support

## Mocking Best Practices

- Mock external boundaries (network, storage, timers).
- Keep mocks minimal and reset between tests.
- Avoid over-mocking UI primitives.
