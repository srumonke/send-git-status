# send-git-status

Demo repo for the Harness CI **Send status to Git** (`sendGitStatus`) stage setting.

It answers three questions in one PR:

1. Can I customise the GitHub check name on a native Harness CI stage?
2. Why does a stage I never enabled the toggle for still post a check?
3. Can I suppress the check for specific stages?

## The pipeline

`send-git-status-demo` has four stages, each configured differently on purpose. Open a PR and
you should see exactly **two** checks, not four.

| Stage | Type | `sendGitStatus` | Check on the PR |
|---|---|---|---|
| `build` | CI | `enabled: true`, `name: harness/ci/build` | `send-git-status-demo - harness/ci/build` |
| `unit tests` | CI | *absent* | `send-git-status-demo - unit tests` |
| `deploy dev` | CI | `enabled: false` | none — suppressed |
| `notify` | Custom | n/a | none — only CI stages export build status |

## What each stage proves

**`build` — custom name.** `sendGitStatus.enabled: true` with a `name` makes the Harness Pipeline
service (not CI) post the check for PR builds, using your name. CI detects the custom config and
skips its own update, so you get one check, not a duplicate.

The catch: the posted name is **`Pipeline Name - Custom Name`**. The pipeline-name prefix is not
removable, so this stage lands as `send-git-status-demo - harness/ci/build`, *not* a bare
`harness/ci/build`. That matters if you want one globally-enforced required check string across
repos — see [Limitations](#limitations).

**`unit tests` — the trap.** No `sendGitStatus` block at all. This is *not* the same as disabled;
"not configured" is the legacy default, where CI posts `Pipeline Name - Stage Name` for every build
type. This is why a stage whose toggle you left off in a stage template still shows up on the PR.
A blank toggle in the UI writes nothing to YAML, so you get the default, not silence.

**`deploy dev` — the fix.** Explicit `enabled: false`. No status is sent for any build type. Use
this for stages that shouldn't gate a merge — a dev deploy that just copies a `.zip` to S3, for
instance.

**`notify` — the other fix.** A Custom stage. Build status is only exported for CI stages, so
converting a stage that isn't really a build removes it from checks structurally, with no
`sendGitStatus` config needed at all.

## Setup

Prerequisites:

- Feature flag **`PIPE_ENABLE_SEND_STATUS_TO_GIT`** enabled on the account. Contact Harness
  Support. The field renders in the UI whether or not the flag is on — if your checks still read
  `Pipeline - Stage` after saving a custom name, the flag is the first thing to check.
- The build must be triggered by a **Pull Request** event. Custom names apply to PR builds only;
  branch, manual, and tag builds fall back to `Pipeline Name - Stage Name`.
- Git connector needs **API access** with write permission for status checks.

Then:

1. Import `.harness/send-git-status-demo.yaml` into the Harness project (or point a remote pipeline
   at it).
2. Create a PR webhook trigger on this repo — `.harness/trigger-pr.yaml` has one.
3. Open a PR against `main`. Touch `app/index.js` so there's a real diff.
4. Compare the checks on the PR against the table above.

## Verifying

```bash
# Checks on PR #1, as GitHub sees them
gh pr checks 1
gh api repos/srumonke/send-git-status/commits/$(gh pr view 1 --json headRefOid -q .headRefOid)/status \
  | jq -r '.statuses[].context'
```

Expect two contexts. `deploy dev` and `notify` should be absent.

## Limitations

- The `Pipeline Name - ` prefix cannot be removed. A single identical required-check string across
  many repos isn't achievable today; the closest workaround is standardising pipeline
  names/identifiers so the required check reads consistently. Worth a feature request if you need
  true global enforcement.
- Custom names are PR-only. Branch and tag builds ignore the custom name.
- Harness can't collapse multiple CI stages into one aggregate pipeline-level check.
- A skipped stage reports **Success** on the PR, not "skipped".
- Checks are listed alphabetically on the PR, not in execution order.
- Failed pipelines don't block merges on their own — you still need branch protection rules in
  GitHub naming the checks as required.

## Docs

- [Send Stage Execution Status to Git on Pull Requests](https://developer.harness.io/docs/platform/triggers/triggering-pipelines#send-stage-execution-status-to-git-on-pull-requests)
- [SCM status checks](https://developer.harness.io/docs/continuous-integration/use-ci/codebase-configuration/scm-status-checks)
- [CI stage settings — Advanced](https://developer.harness.io/docs/continuous-integration/use-ci/set-up-build-infrastructure/ci-stage-settings#advanced)
