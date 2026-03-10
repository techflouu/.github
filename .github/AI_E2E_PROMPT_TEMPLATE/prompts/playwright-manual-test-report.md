---
mode: agent
description: 'Test a site using Playwright CLI and generate a Playwright spec file'
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

# E2E Test Generation Instructions

1. Use the `playwright-cli` commands (e.g. `playwright-cli open <url>`, `playwright-cli click <ref>`, `playwright-cli snapshot`) to navigate the website and manually test the scenario provided by the user. If no scenario is provided, ask the user to provide one. Do not generate any code until you have explored the website and identified the key user flows by navigating the live site.
2. Based on the components and paths involved, perform the described interactions via CLI.
3. Observe and verify the expected behavior, focusing on accessibility, UI structure, and user experience.
4. **Generate a Playwright test spec file** (`.spec.e2e.ts`) with all discovered test cases. Each test should use `@playwright/test` imports and follow proper Playwright test patterns.
5. Save the test file to `/__tests_e2e__/<employer_or_jobseeker>/<feature-name>.spec.e2e.ts`
6. **Run the generated tests** using `npx playwright test <path-to-spec> --project=chromium` and use the CLI output to identify and fix any failing tests until all pass.
7. End the task once the tests pass.

---

## Output Format

Generate a Playwright spec file following this structure:

```typescript
import { test, expect } from '@playwright/test'

const BASE_URL = 'http://localhost:3000'

test.describe('<Feature Name> - <User State>', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto(`${BASE_URL}/<route>`)
  })

  test('<ID>: <Scenario description>', async ({ page }) => {
    // Arrange: locate elements
    // Act: perform interactions
    // Assert: verify expected behavior
  })
})
```

## Test Writing Guidelines

- **Use Playwright best practices**: prefer `getByRole`, `getByText`, `getByLabel` over CSS selectors when possible.
- **Scope selectors carefully**: avoid strict mode violations by scoping locators to parent elements (e.g. `page.getByRole('banner')` for NavBar) or using `.first()` / `.nth()` when multiple matches are expected.
- **Group tests logically**: use `test.describe` blocks to separate anonymous vs authenticated flows, navigation flows, etc.
- **Unique test IDs**: prefix each test name with an ID (e.g. `EC-001`, `JL-001`) for traceability.
- **Handle external links**: if links open in new tabs (e.g. via `target="_blank"`), verify `href` attributes instead of clicking and asserting URL changes.
- **Verify all tests pass**: run the spec after generation and fix any selector issues before finalizing.

---

## File Naming Convention

- _Directory:_ `/__tests_e2e__/<employer_or_jobseeker>/`
- _Filename:_ `<feature-name>.spec.e2e.ts`
- _Example:_ `/__tests_e2e__/employer/job-application.spec.e2e.ts`

## Running Tests

```bash
# Headless (CI-friendly)
npm run test:e2e:headless

# Interactive UI mode
npm run test:e2e:ui
```
