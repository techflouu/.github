# Running E2E Tests with Playwright and AI

This guide provides instructions on how to leverage the Playwright CLI to automatically generate and execute End-to-End (E2E) Playwright test spec files using AI.

## Prerequisites & Setup

Before using the AI to write and test Playwright scripts, you need to install the Microsoft Playwright CLI and its AI skills.

```bash
# 1. Install playwright-cli globally
npm install -g @playwright/cli@latest

# 2. Initialize it in your project (adds AI skills)
playwright-cli install --skills
```

## Workflow Summary

The general workflow for utilizing AI-driven E2E tests through Playwright is:

1. **Configure the Test Generation Template**
2. **Provide Context (PRD & Test Cases)**
3. **Prompt the AI to Generate & Execute Tests**

### 1. Configure the Test Generation Template

First, configure the prompt template that the AI will use to standardize test generation. This determines what context and formatting the AI must follow.

- Open your project's Playwright test template (e.g., `.github/prompts/playwright-manual-test-report.md`).
- Tweak the prompt instructions as needed.
- **Specify the AI Model**: Update the YAML frontmatter to define which model you want the AI assistant to use for this execution (e.g., `model: 'Gemini 1.5 Pro'`).

```markdown
---
description: 'Playwright E2E Test Generator'
globs:
  - '**/*.spec.ts'
model: 'Gemini 1.5 Pro'
---
```

### 2. Provide Feature Context (PRD)

The AI needs to understand the expected behavior and acceptance criteria of the feature being tested.

- Locate the Product Requirements Document (PRD) for the feature.
- Ensure the PRD is structured clearly and placed in a location accessible to the AI (e.g., inside a `docs/` or `__tests_e2e__/` directory).
- By linking or referencing the PRD in your initial prompt, you ensure the AI validates the UI against actual business requirements.

### 3. Prompting the AI (Test Generation & Execution)

The final step is to ask the AI assistant to generate and run the tests. Your prompt should act as the trigger, giving the AI the exact boundaries of what needs to be tested.

**Prompting Example:**

> Please generate and run E2E tests for the Jobseeker `/jobs` list feature using Playwright.

> 1. Use the PRD located at `docs/features/jobseeker-jobs.md` as context for expected behavior.
> 2. Use the test generation template `.github/prompts/playwright-manual-test-report.md`.
> 3. Please cover the following test cases:
>    - TC01: Verify job cards render with title, company name, and location.
>    - TC02: Verify that clicking a job opening triggers the job details preview.
>    - TC03: Verify that the pagination works correctly for job lists > 10.
>
> Proceed step-by-step and notify me if there are critical blockers or failed tests.

### 4. Output

The AI will generate a Playwright spec file at:

```
__tests_e2e__/<employer_or_jobseeker>/<feature-name>.spec.ts
```

The spec file will contain proper `@playwright/test` imports, structured `test.describe` blocks, and individual `test()` cases with assertions.

After generating the spec, the AI will run the tests using:

```bash
npx playwright test __tests_e2e__/<path>.spec.ts --project=chromium
```

Any failing tests will be fixed until all pass.

---

## Running Tests

```bash
# Headless (CI-friendly)
npm run test:e2e:headless

# Interactive UI mode
npm run test:e2e:ui
```

---

### Tips for Success

- **Detailed Test Cases:** The more specific your test cases (e.g., explicitly stating elements to look for, specific validation messages), the more accurate the generated test file will be.
- **Environment Setup:** Ensure your local development server is running and seeded with necessary test data before instructing the AI to begin testing.
- **Review the spec:** After generation, open the `.spec.ts` file and review the selectors and assertions to ensure they match your app's DOM structure.
