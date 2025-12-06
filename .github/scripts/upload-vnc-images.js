const fs = require('fs');
const { execSync } = require('child_process');

module.exports = async ({ github, context, core }) => {
  const pr = context.payload.pull_request;
  const owner = pr ? pr.head.repo.owner.login : context.repo.owner;
  const repo = pr ? pr.head.repo.name : context.repo.repo;
  const branch = pr ? pr.head.ref : process.env.GITHUB_REF_NAME;
  const prNumber = pr?.number ?? 'ci';

  if (!branch) {
    core.setFailed('No branch ref available for repository upload.');
    return { smoke_image_url: '', integration_image_url: '' };
  }

  const upsertFile = async (path, message, content) => {
    let existingSha;
    try {
      const existing = await github.rest.repos.getContent({ owner, repo, path, ref: branch });
      if (!Array.isArray(existing.data)) {
        existingSha = existing.data.sha;
      }
    } catch (error) {
      if (error.status !== 404) {
        throw error;
      }
    }

    return github.rest.repos.createOrUpdateFileContents({
      owner,
      repo,
      path,
      message,
      content,
      branch,
      sha: existingSha,
    });
  };

  const ensurePngFromPpm = (pngPath) => {
    const ppmPath = pngPath.replace(/\.png$/, '.ppm');

    if (fs.existsSync(pngPath)) {
      return;
    }

    if (!fs.existsSync(ppmPath)) {
      core.info(`PNG not found at ${pngPath} and no PPM fallback at ${ppmPath}.`);
      return;
    }

    try {
      execSync(`convert ${ppmPath} ${pngPath}`, { stdio: 'inherit' });
      core.info(`Converted ${ppmPath} to ${pngPath} for repository upload.`);
    } catch (error) {
      core.warning(`Failed to convert ${ppmPath} to PNG: ${error.message}`);
    }
  };

  const screenshots = [
    {
      label: 'smoke',
      source: 'qemu-screen-smoke.png',
      upload: `.github/pr-images/${process.env.PR_SMOKE_IMAGE_NAME}`,
      readmePath: 'docs/splash-screen.png',
    },
    {
      label: 'integration',
      source: 'qemu-screen-integration.png',
      upload: `.github/pr-images/${process.env.PR_INTEGRATION_IMAGE_NAME}`,
      readmePath: 'docs/integration-screen.png',
    },
    {
      label: 'integration_terminal',
      source: 'qemu-screen-integration-terminal.png',
      upload: `.github/pr-images/${process.env.PR_INTEGRATION_TERMINAL_IMAGE_NAME}`,
      readmePath: 'docs/integration-terminal-screen.png',
    },
  ];

  const results = {};
  for (const shot of screenshots) {
    ensurePngFromPpm(shot.source);

    if (!fs.existsSync(shot.source)) {
      core.info(`No ${shot.label} screenshot found at ${shot.source}; skipping upload.`);
      continue;
    }

    const content = fs.readFileSync(shot.source).toString('base64');
    const uploadResponse = await upsertFile(shot.upload, `Add ${shot.label} VNC screenshot for #${prNumber}`, content);
    await upsertFile(shot.readmePath, `Update README ${shot.label} screen for #${prNumber}`, content);

    const imageUrl = uploadResponse.data.content.download_url
      || `https://raw.githubusercontent.com/${owner}/${repo}/${branch}/${shot.upload}`;
    core.info(`Uploaded ${shot.label} VNC screenshot to ${imageUrl}`);
    core.info(`Updated README screenshot at ${shot.readmePath}`);
    results[`${shot.label}_image_url`] = imageUrl;
  }

  core.setOutput('smoke_image_url', results.smoke_image_url || '');
  core.setOutput('integration_image_url', results.integration_image_url || '');
  core.setOutput('integration_terminal_image_url', results.integration_terminal_image_url || '');
  return results;
};
