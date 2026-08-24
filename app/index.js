// Trivial app so the demo pipeline has something to build, lint, and test.
// Edit this file in a PR branch to trigger the pipeline and inspect the resulting checks.

function greet(name) {
  if (!name) {
    throw new Error('name is required');
  }
  return `hello, ${name}`;
}

module.exports = { greet };

// Touched to trigger the demo pipeline.

// Retest with sendGitStatus at correct YAML path.

// Final retest: deploy_dev suppression.
