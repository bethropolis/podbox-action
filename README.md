# podbox-action

A GitHub Action that builds [podbox](https://github.com/bethropolis/podbox)
environments from TOML files in your repo and pushes them to GHCR as prebuilt
images.

Once an image is published, anyone can use it:

```bash
podbox create ghcr.io/<owner>/<repo>/<key>
```


## Quick start

```yaml
# .github/workflows/publish.yml
name: publish
on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read
  packages: write

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: bethropolis/podbox-action@v1
```

Pull requests build and validate the images but never push them.

## What it does

The action installs a pinned podbox release, checks that it supports
publishing, logs in to the registry, and runs `podbox publish`. podbox does
the real work: reading your configs, building each image, tagging, and
skipping images whose inputs haven't changed. The action passes inputs in and
turns podbox's event stream into step outputs and a job summary.

Only the `[image]` section of a config ends up in the image. Container
settings, dotfiles and provision steps stay with whoever uses the image. Your
`[integration]` section is written into the image as `podbox.integration.*`
labels, so `podbox create <ref>` starts from the same defaults you chose.

Each image is built with `docker buildx`. Pushing needs `packages: write`;
nothing else beyond `contents: read` is required.

## Finding your images

With no configuration, podbox looks for images in this order:

1. `images.toml` at the repo root.
2. `envs/*.toml`, one image per file. The key is the file name without `.toml`.
3. A single `podbox.toml`.

| Source | Published as |
|--------|--------------|
| Manifest entry or `envs/<key>.toml` | `ghcr.io/<owner>/<repo>/<key>` |
| A lone `podbox.toml` | `ghcr.io/<owner>/<repo>` |
| Entry with `name = "..."` | exactly that ref |

Owner, repo and key are lowercased, since GHCR requires it. A manifest entry
always includes its key, so adding a second image never renames the first.

### images.toml

```toml
schema_version = 1
registry  = "ghcr.io"            # default
platforms = ["linux/amd64"]      # default, and the only value in v1
tags      = ["latest", "sha"]    # defaults for every image

[images.dev]
config = "envs/dev.toml"

[images.gaming]
config = "envs/gaming.toml"
tags   = ["latest", "nightly"]
# name = "ghcr.io/me/gaming"     # full ref override
```

Tag values are tokens: `latest` (default-branch pushes and version tags
only), `sha` (`sha-<7 chars>`), `semver` (`1.2.3`, `1.2` and `1` on `v*` tags),
`date` (`YYYYMMDD`) and `branch`. Anything else is used as a literal tag.

## Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `images` | *(empty)* | Manifest path. Empty means use the discovery order above |
| `only` | *(empty)* | Space-separated image keys to build |
| `push` | `auto` | `auto` pushes except on pull requests. `true` and `false` force it, but pull requests never push |
| `force` | `false` | Rebuild even if the remote image is up to date |
| `registry` | `ghcr.io` | Registry to log in to and publish to |
| `token` | `${{ github.token }}` | Registry password |
| `podbox-version` | `latest` | podbox release tag to install |
| `working-directory` | `.` | Where to look for the manifest or configs |

## Outputs

| Output | Description |
|--------|-------------|
| `images` | JSON array of `{key, ref, digest, tags, pushed, skipped, first_push, error}` |
| `pushed` | Number of images pushed |
| `skipped` | Number skipped because they were already up to date |

## Recipes

Baked images go stale when their base image does. To refresh them, rebuild on
a schedule with `force: "true"`. See
[examples/scheduled-refresh.yml](examples/scheduled-refresh.yml).

For several environments in one repo, add an `images.toml` and start from
[examples/multi-image.yml](examples/multi-image.yml). Unchanged images are
skipped on their own.

## After the first push

GHCR creates new packages as private. To let other people pull an image
without logging in, open the package on GitHub and choose *Package settings,
Change visibility, Public*. Do this once per image, since every key is a
separate package. Public can't be switched back to private. The job summary
lists the packages that need it after each image's first push.

## Requirements

- A GitHub-hosted `ubuntu-latest` runner, or a self-hosted Linux runner with
  `docker buildx`, `curl` and `jq`.
- A podbox release that provides `publish` and `emit_context` (see the status
  note above).
- Architecture is `linux/amd64` only for now. The guest binary embedded in an
  image is built per architecture, so arm64 needs separate work (see the
  roadmap).

## Security

- Third-party actions in this repo are pinned by commit SHA. Pin this action
  by SHA in your own workflows if you want the same.
- podbox is installed by running its own installer from the resolved release
  tag. Checksum verification is whatever that installer does; the note at the
  top of `scripts/install.sh` lists what to confirm.
- Pull requests never push. On pull requests from forks the token is read-only
  anyway.

## Development

```bash
mise install      # shellcheck, just, bats, actionlint, zizmor
just check        # lint plus the unit tests
just test         # unit tests only
```

Unit tests run offline against a stub `podbox` in
`tests/fixtures/fake-podbox/`. The `self-test` job in
`.github/workflows/ci.yml` runs the real action. It's off until podbox ships
`publish`; turn it on by setting the repository variable
`PODBOX_PUBLISH_AVAILABLE` to `true`.


## License

MIT
