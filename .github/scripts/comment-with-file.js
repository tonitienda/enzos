const fs = require('fs');

module.exports = async ({ github, context, core }, bodyPath) => {
  const body = fs.readFileSync(bodyPath, 'utf8');

  await github.rest.issues.createComment({
    owner: context.repo.owner,
    repo: context.repo.repo,
    issue_number: context.issue.number,
    body,
  });

  core.info(`Posted PR comment from ${bodyPath}.`);
};
