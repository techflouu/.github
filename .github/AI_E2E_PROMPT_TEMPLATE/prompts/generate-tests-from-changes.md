---
mode: agent
description: 'Auto-generate tests based on uncommitted changes'
tools:
  [
    'changes',
    'search/codebase',
    'edit/editFiles',
    'fetch',
    'runCommands',
    'runTasks',
    'runTests',
    'search',
    'search/searchResults',
    'runCommands/terminalLastCommand',
    'runCommands/terminalSelection',
    'testFailure'
  ]
model: 'Gemini 3.1 Pro (High)'
---

💡

# Test Generation from Uncommitted Changes

This prompt instructs the AI to automatically analyze your current uncommitted `git` changes, determine the affected features, and generate or update the necessary Unit and E2E tests.

## 1. Analyze Changes

- Run `git diff` or use internal source-control tools to examine all currently uncommitted changes in the repository.
- Identify which files have been modified, added, or deleted.
- Map these changes to specific features or components (e.g., "Job Seeker Settings Profile", "Employer Analytics Dashboard").

## 2. Determine Required Tests

Based on the intent of the changes:

- **Unit Tests (`<file>.test.ts`)**: Identify if any core utilities, hooks, constants, or isolated UI components were changed. Determine what unit tests need to be added or modified to cover the new logic.
- **E2E Tests (`.spec.ts`)**: Identify if any page-level behavior, user flows, API integrations, or overall layouts were modified. Determine what Playwright End-to-End tests need to be created or updated in `__tests_e2e__/`.

## 3. Generate and Update Tests

### Unit Tests

- Create or update Jest unit tests next to the changed files (or in the designated `__tests__` directory).
- Ensure high coverage for edge cases, error states, and standard success states.
- Follow existing project testing patterns.

### E2E Tests (Playwright)

- Create or update `.spec.e2e.ts` files in the appropriate subdirectory inside `__tests_e2e__/`.
- Ensure you navigate to the correct routes, use `getByRole` or `getByText` locators, and write robust assertions.
- Run the Playwright CLI tests (`npm run test:e2e:headless`) to visually verify failures in the terminal and write accurate selectors.

## 4. Verify Tests

- Run the localized unit tests you modified using `npm run test` (or a targeted jest command).
- Run the E2E tests headlessly using `npm run test:e2e:headless`.
- If any test fails, analyze the output, fix the test assertions or mock data, and re-run until all tests pass successfully.

---

**Execution:**
When triggered, the AI will immediately begin analyzing the `git diff` and proceed through the steps above, stopping only when all affected files have corresponding passing tests.
