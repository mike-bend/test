# Slash Commands

This repository supports **slash commands** – type a command in a pull-request comment and the corresponding CI job will run on demand, with its result reported directly on the PR.

---

## Usage

In any open pull request, leave a comment containing a slash command on its own line:

```
/run-tests
```

The `slash-command-dispatch` workflow will:

1. Verify you have **write access** to the repository.
2. React to your comment with 👀 so you know it was received.
3. Trigger the corresponding CI job.
4. The job creates a **GitHub Check Run** on the PR's head commit, so its status appears in the PR's *Checks* tab just like any other CI job.

---

## Available commands

| Command | Description |
|---|---|
| `/run-tests` | Run the test suite against the PR's head commit. |

---

## Setting a slash-command job as a required check

Because each command creates a named **Check Run** on the PR commit, you can require it to pass before merging:

1. Go to **Settings → Branches** in your repository.
2. Edit (or create) a branch protection rule for your target branch (e.g. `main`).
3. Enable **Require status checks to pass before merging**.
4. Search for the check name (e.g. `run-tests`) and add it.

> **Note:** The check name in the branch protection rule must exactly match the `name:` field used in the workflow's `checks.create` call.

---

## Adding a new slash command

### 1. Add the command to the dispatcher

In `.github/workflows/slash-command-dispatch.yml`, add a new dispatch step following the pattern of the existing `/run-tests` step:

```yaml
- name: Dispatch /my-command
  if: >
    steps.permission.outputs.allowed == 'true' &&
    steps.parse.outputs.command == 'my-command'
  uses: actions/github-script@v7
  with:
    script: |
      await github.rest.repos.createDispatchEvent({
        owner:      context.repo.owner,
        repo:       context.repo.repo,
        event_type: 'slash-my-command',
        client_payload: {
          pr_number: context.issue.number,
          sha:       '${{ steps.pr.outputs.sha }}',
          ref:       '${{ steps.pr.outputs.ref }}',
          actor:     context.actor,
        },
      });
```

Also update the unknown-command warning step's command list.

### 2. Create the command workflow

Create `.github/workflows/my-command.yml` triggered by the `repository_dispatch` event:

```yaml
name: my-command

on:
  repository_dispatch:
    types: [slash-my-command]

permissions:
  checks: write
  contents: read

jobs:
  my-command:
    name: my-command        # This name appears as the check in the PR UI
    runs-on: ubuntu-latest
    steps:
      - name: Create check run (in_progress)
        id: check
        uses: actions/github-script@v7
        with:
          result-encoding: string
          script: |
            const { data } = await github.rest.checks.create({
              owner:      context.repo.owner,
              repo:       context.repo.repo,
              name:       'my-command',
              head_sha:   '${{ github.event.client_payload.sha }}',
              status:     'in_progress',
              started_at: new Date().toISOString(),
              details_url: `${context.serverUrl}/${context.repo.owner}/${context.repo.repo}/actions/runs/${context.runId}`,
            });
            return String(data.id);

      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.client_payload.sha }}

      - name: Run my-command
        run: |
          # your commands here

      - name: Complete check run (success)
        if: success()
        uses: actions/github-script@v7
        with:
          script: |
            await github.rest.checks.update({
              owner:        context.repo.owner,
              repo:         context.repo.repo,
              check_run_id: ${{ steps.check.outputs.result }},
              status:       'completed',
              conclusion:   'success',
              completed_at: new Date().toISOString(),
            });

      - name: Complete check run (failure)
        if: failure()
        uses: actions/github-script@v7
        with:
          script: |
            await github.rest.checks.update({
              owner:        context.repo.owner,
              repo:         context.repo.repo,
              check_run_id: ${{ steps.check.outputs.result }},
              status:       'completed',
              conclusion:   'failure',
              completed_at: new Date().toISOString(),
            });
```

The `name:` field in the `checks.create` call (e.g. `my-command`) is what you'll search for when configuring required status checks in branch protection rules.

---

## How it works

```
PR comment: /run-tests
       │
       ▼
slash-command-dispatch.yml  (issue_comment trigger)
  • verify commenter has write access
  • react with 👀
  • repository_dispatch  →  event_type: slash-run-tests
       │
       ▼
run-tests.yml  (repository_dispatch trigger)
  • checks.create  →  check run "run-tests" = in_progress  (visible on PR)
  • checkout PR commit
  • run tests
  • checks.update  →  check run "run-tests" = success / failure
```
