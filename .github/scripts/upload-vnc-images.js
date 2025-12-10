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

  const screenshots = new Set();
  for (const entry of fs.readdirSync(process.cwd())) {
    if (entry.match(/^qemu-screen-.*\.png$/)) {
      screenshots.add(entry);
    }
    if (entry.match(/^qemu-screen-.*\.ppm$/)) {
      const pngName = entry.replace(/\.ppm$/, '.png');
      ensurePngFromPpm(pngName);
      screenshots.add(pngName);
    }
  }

  const uploadedImages = [];
  for (const fileName of Array.from(screenshots).sort()) {
    const sourcePath = `./${fileName}`;
    if (!fs.existsSync(sourcePath)) {
      core.info(`Skipping missing screenshot ${sourcePath}.`);
      continue;
    }

    const uploadPath = `.github/pr-images/${fileName}`;
    const content = fs.readFileSync(sourcePath).toString('base64');
    const uploadResponse = await upsertFile(
      uploadPath,
      `Add ${fileName} VNC screenshot for #${prNumber}`,
      content,
    );

    const imageUrl = uploadResponse.data.content.download_url
      || `https://raw.githubusercontent.com/${owner}/${repo}/${branch}/${uploadPath}`;
    core.info(`Uploaded ${fileName} to ${imageUrl}`);
    uploadedImages.push({ name: fileName, url: imageUrl });
  }

  core.setOutput(
    'images',
    uploadedImages.map((image) => `${image.name}|${image.url}`).join('\n'),
  );

  return { uploadedImages };
};
