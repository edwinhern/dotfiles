---
description: "Generate constitutional-compliant commit messages following quality standards and best practices"
---

# Commit and Push Changes

## Instructions

This prompt guides you through committing and pushing your changes for a JIRA ticket. Replace `{TICKET_NUMBER}` with the actual JIRA ticket number (e.g., BC724-550).

## Prerequisites

- All tests passing
- Linting checks passing
- Changes have been validated
- Currently on the feature branch

## Commit Message Format

Always use the enforced format:

```
<type>: {TICKET_NUMBER} <description>
```

### Valid types:

Behavioral Changes (Affect functionality)

- `feat:` - New features (new jisp parsing, UI components, solver algorithms)
- `fix:` - Bug fixes (validation errors, parsing issues, solver bugs)
- `test:` - Test additions or modifications
- `perf:` - Performance improvements (solver optimization, parsing speed)

Structural Changes (No functional impact)

- `refactor:` - Code restructuring without behavior change
- `docs:` - Documentation updates
- `chore:` - Maintenance tasks, dependency updates
- `style:` - Code style/formatting changes
- `specs:` - Specification development and updates

Examples:

- `feat: BC724-550 Add new experiment hooks architecture`
- `fix: BC724-550 Resolve button alignment issue`
- `refactor: BC724-550 Consolidate utility functions`
- `test: BC724-550 Add missing test coverage for component`

## Git Operations Workflow

### 1. Verify Current Branch

```bash
# Confirm you're on the feature branch
git branch --show-current
# Should output: feature/{TICKET_NUMBER}
```

### 2. Review Changes

```bash
# View all modified files
git status

# Review specific changes
git diff

# Review staged changes
git diff --staged
```

### 3. Stage Changes

```bash
# Stage all changes
git add .

# Or stage specific files
git add <file1> <file2>

# Verify staged files
git status
```

### 4. Create Commit

```bash
# Commit with proper format
git commit -m "<type>: {TICKET_NUMBER} <description_of_changes>"
```

### 5. Push to Remote

```bash
# Push feature branch to origin
git push origin feature/{TICKET_NUMBER}

# If this is the first push, the command above will work
# For subsequent pushes to the same branch
git push
```

### 6. Verify Push

```bash
# Confirm the branch exists on remote
git branch -r | grep feature/{TICKET_NUMBER}
```

## Pre-Push Final Checklist

Before pushing, verify:

- [ ] All tests pass: `npm test`
- [ ] Linting passes: `npm run lint`
- [ ] StaticType pass: `npm run check-types`
- [ ] Build succeeds (if applicable): `npm run build:client`
- [ ] Commit message follows format: `<type>: {TICKET_NUMBER} <description>`
- [ ] On correct feature branch: `git branch --show-current`
- [ ] All changes staged and committed: `git status` shows clean working tree

## Example Usage for BC724-550

```bash
# Verify branch
git branch --show-current
# Output: feature/BS-86067

# Review changes
git status
git diff

# Stage all changes
git add .

# Commit with proper message
git commit -m "feat: BC724-550 Replace useDetermineVariant calls with VariantsByCart pattern"

# Push to remote
git push origin feature/BC724-550
```

## Common Issues and Solutions

### Commit Message Validation Fails

If your commit message doesn't follow the required format:

```bash
# Amend the last commit message
git commit --amend -m "<type>: {TICKET_NUMBER} <new_description>"
```

#### Need to Add More Changes Before Pushing

```bash
# Stage additional files
git add <files>

# Amend the previous commit
git commit --amend --no-edit

# Or create a new commit
git commit -m "<type>: {TICKET_NUMBER} <additional_changes>"
```

### Branch Doesn't Exist on Remote Yet

```bash
# Set upstream and push
git push -u origin feature/{TICKET_NUMBER}
```

### Push Rejected (Remote has Changes)

```bash
# Pull and rebase
git pull --rebase origin feature/{TICKET_NUMBER}
# Resolve any conflicts if they occur
# Then continue the rebase
git rebase --continue

# Push again
git push
```

## Next Steps

Once your changes are pushed:

1. Verify the branch appears in GitHub
2. Proceed to create a pull request using the create-pull-request prompt
3. Follow the project's PR template guidelines

## Notes

- Never force push unless absolutely necessary and you understand the implications
- Always verify tests pass before pushing
- Keep commits focused and atomic
- Use descriptive commit messages that explain the "why" not just the "what"
