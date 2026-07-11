# `build-rails-image`

Composite action that builds a Sure Rails container image. Centralizes the `docker buildx` invocation used by both `release-rails.yml` and `ops-preview.yml` so the two paths cannot drift.

## Modes

### `push`

- Builds a multi-arch (linux/amd64 + linux/arm64) image with `docker buildx build --push`.
- Image reference: `<registry>/<repo>:<tag>` (default registry `ghcr.io`).
- Skips the push when `push: "false"` — the image is still built and inspected, just not pushed.

### `preview`

- Builds a single-arch (linux/amd64) image with `docker build` from `Dockerfile.preview`.
- Emits three artifacts in `$RUNNER_TEMP`:
  - `sure-preview-image.tar.gz` — gzipped `docker save` output
  - `sure-preview-image.sha256` — SHA-256 of the archive
  - `sure-preview-image.manifest.json` — JSON with `artifactVersion`, `archiveSha256`, `headSha`, `imageId` (sha256:...), `imageTag`, `prNumber`
- The image tag is `sure-preview-pr-<pr-number>:<head-sha>`, matching the contract that the Cloudflare worker (`workers/preview/deploy`) verifies.

## Inputs

| Input        | Required | Type    | Default       | Description                                              |
| ------------ | -------- | ------- | ------------- | -------------------------------------------------------- |
| `mode`       | yes      | enum    | —             | `push` or `preview`                                      |
| `push`       | no       | string  | `"false"`     | `push` mode only: whether to push to the registry        |
| `tag`        | yes      | string  | —             | Image tag (`push` mode)                                  |
| `sha`        | yes      | string  | —             | Head commit SHA                                          |
| `pr-number`  | no       | string  | `""`          | `preview` mode only: PR number                           |
| `registry`   | no       | string  | `ghcr.io`     | `push` mode only: container registry                     |
| `image-name` | no       | string  | repo          | `push` mode only: image name                             |

## Outputs

| Output         | Description                                                              |
| -------------- | ------------------------------------------------------------------------ |
| `image-tag`    | Image:tag that was built                                                 |
| `image-id`     | sha256 image id (matches `manifest.imageId` in preview mode)            |
| `archive-path` | Path to the tarball (preview mode only)                                  |
| `manifest-path`| Path to the manifest JSON (preview mode only)                           |

## Caller contract

```yaml
- uses: ./.github/actions/build-rails-image
  with:
    mode: preview
    sha: ${{ github.event.pull_request.head.sha }}
    pr-number: ${{ github.event.pull_request.number }}
```

```yaml
- uses: ./.github/actions/build-rails-image
  with:
    mode: push
    push: ${{ github.event.inputs.push || 'false' }}
    tag: sha-${{ github.sha }}
    sha: ${{ github.sha }}
```
