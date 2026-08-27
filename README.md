# send-git-status

Demo repo for the Harness CI **Send status to Git** (`sendGitStatus`) stage setting test3.

Everything below was verified by running it — see [Verified results](#verified-results).

It answers three questions in one PR:

1. Can I customise the GitHub check name on a native Harness CI stage?
2. Why does a stage I never enabled the toggle for still post a check?
3. Can I suppress the check for specific stages?

## ⚠️ The docs put `sendGitStatus` in the wrong place

The [Harness docs](https://developer.harness.io/docs/platform/triggers/triggering-pipelines#configuration-examples)
show it nested under `advanced:`. That does not work. Harness accepts and stores the YAML — it
validates, it round-trips, `entityValidityDetails.valid` is `true` — but the field is inert:
the Visual editor renders the toggle as **off** with a blank Name, and the runtime ignores it
entirely.

`sendGitStatus` is a **sibling of `spec:`**, at the stage top level:

```yaml
# ✅ correct — what the Visual editor actually writes
- stage:
    identifier: build
    type: CI
    sendGitStatus:
      enabled: true
      name: harness/ci/build
    spec:
      ...

# ❌ wrong — what the docs show. Silently ignored.
- stage:
    identifier: build
    type: CI
    spec:
      ...
    advanced:
      sendGitStatus:
        enabled: true
        name: harness/ci/build
```

This is consistent with `when`, `failureStrategies`, `strategy`, and `delegateSelectors`, which
all sit at the stage top level too, despite also living on the UI's **Advanced** tab. There is no
`advanced` property on a CI stage at all.

If a custom name isn't taking effect, check this before you suspect the feature flag.

## The pipeline

`send-git-status-demo` has four stages, each configured differently on purpose. Open a PR and you
get exactly **two** checks, not four.

| Stage | Type | `sendGitStatus` | Check on the PR |
|---|---|---|---|
| `build` | CI | `enabled: true`, `name: harness/ci/build` | `send_git_status_demo-harness/ci/build` |
| `unit tests` | CI | *absent* | `send_git_status_demo-unit_tests` |
| `deploy dev` | CI | `enabled: false` | none — suppressed |
| `notify` | Custom | n/a | none — only CI stages export build status |

## What each stage proves

**`build` — custom name.** `enabled: true` with a `name` makes the check use your name instead of
the stage identifier.

The catch: the posted context is **`${pipelineIdentifier}-${name}`**, so this lands as
`send_git_status_demo-harness/ci/build`, *not* a bare `harness/ci/build`. The pipeline-identifier
prefix is not removable — see [Limitations](#limitations). Slashes in the name are fine; GitHub
accepts them.

Note this is the *identifier*, not the display name, and there are no spaces around the hyphen.
The docs describe the format as `Pipeline Name - Custom Name`, which is wrong on both counts.

**`unit tests` — the trap.** No `sendGitStatus` block at all. This is *not* the same as disabled;
"not configured" is the legacy default, where CI posts `${pipelineIdentifier}-${stageIdentifier}`
for every build type.

This is why a stage whose toggle you left off in a stage template still shows up on the PR. A blank
toggle in the UI writes nothing to YAML, and nothing means "default", not "off". If you want a
stage silent, you must say so explicitly.

**`deploy dev` — the fix.** Explicit `enabled: false`. The stage still **runs**, and posts no
status for any build type. Use this for stages that shouldn't gate a merge — a dev deploy that just
copies a `.zip` to S3, for instance.

**`notify` — the other fix.** A Custom stage. Build status is only exported for CI stages, so
converting a stage that isn't really a build removes it from checks structurally, with no
`sendGitStatus` config needed at all. Often the more honest fix for a stage that was only typed
`CI` by accident.

## Setup

Prerequisites:

- Feature flag **`PIPE_ENABLE_SEND_STATUS_TO_GIT`** enabled on the account. Contact Harness
  Support. The field renders in the UI whether or not the flag is on.
- The build must be triggered by a **Pull Request** event. Custom names apply to PR builds only;
  branch, manual, and tag builds fall back to the stage identifier.
- Git connector needs **API access** with write permission for status checks.

Then:

1. Import `.harness/send-git-status-demo.yaml` into the Harness project.
2. Create a PR webhook trigger — `.harness/trigger-pr.yaml` has one.
3. Open a PR against `main`. Touch `app/index.js` so there's a real diff.
4. Compare the checks on the PR against the table above.

## Verifying

```bash
# Distinct check contexts on PR #1
gh pr checks 1

gh api repos/srumonke/send-git-status/commits/\
$(gh pr view 1 --json headRefOid -q .headRefOid)/status \
  | jq -r '.statuses[].context'
```

Expect two contexts. `deploy dev` and `notify` should be absent.

These are legacy **commit statuses**, not check-runs — `/check-runs` returns `total_count: 0`. If
you're wiring up branch protection, the required checks are commit-status contexts.

To confirm a missing check means suppression rather than a skipped stage, check the execution
reports all four stages succeeded (`successfulStagesCount: 4`).

## Verified results

Commit `db794a6`, execution `sVbd-HY5`, all four stages `Success`:

```
overall: success | distinct contexts: 2
 - 'send_git_status_demo-harness/ci/build' => success
 - 'send_git_status_demo-unit_tests'       => success
```

`deploy_dev` ran for 44s and posted nothing. `notify` posted nothing. Both custom naming and
per-stage suppression work, once the YAML is at the right path.

## Limitations

- The `${pipelineIdentifier}-` prefix cannot be removed. A single identical required-check string
  across many repos isn't achievable today; the closest workaround is standardising pipeline
  identifiers so the required check reads consistently. Worth a feature request if you need true
  global enforcement.
- Custom names are PR-only. Branch and tag builds ignore them.
- Harness can't collapse multiple CI stages into one aggregate pipeline-level check.
- A skipped stage reports **Success** on the PR, not "skipped".
- Checks are listed alphabetically on the PR, not in execution order.
- Failed pipelines don't block merges on their own — you still need branch protection rules in
  GitHub naming the checks as required.
- Updating a pipeline via the API **merges** rather than replaces: a stale `advanced.sendGitStatus`
  block survived an update that omitted it. Read the pipeline back and verify rather than trusting
  the write.

## Docs

- [Send Stage Execution Status to Git on Pull Requests](https://developer.harness.io/docs/platform/triggers/triggering-pipelines#send-stage-execution-status-to-git-on-pull-requests)
  — note the `advanced:` nesting in its examples is wrong
- [SCM status checks](https://developer.harness.io/docs/continuous-integration/use-ci/codebase-configuration/scm-status-checks)
- [CI stage settings — Advanced](https://developer.harness.io/docs/continuous-integration/use-ci/set-up-build-infrastructure/ci-stage-settings#advanced)
