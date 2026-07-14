# Contributing

Thanks for contributing to this chart.

## Scope

This repository publishes an unofficial, community-maintained Helm chart for deploying Stalwart Mail Server in Kubernetes.

## Development prerequisites

- Helm 3.14+
- Kubernetes access for runtime testing (optional but recommended)

## Local workflow

1. Create a branch from `main`.
2. Make your chart/doc changes.
3. Run:

```bash
helm lint .
helm template stalwart . >/tmp/stalwart-rendered.yaml
```

4. If behavior changed, update `README.md` and `values.yaml`.
5. Open a pull request with:
- What changed
- Why it changed
- Any migration/operational impact

## Versioning guidance

- Follow semantic versioning for `Chart.yaml` `version`.
- Bump chart version for any user-visible chart change.
- Update `appVersion` when changing default upstream Stalwart version.
- OCI publishing to GHCR is triggered by pushing a Git tag that matches `v*`.
- Pull requests that change chart-impacting files fail CI unless `Chart.yaml` `version` is increased.

## Pull request expectations

- Keep changes focused and reversible.
- Include validation evidence (lint/render output summary).
- Avoid adding provider-specific assumptions without flags and docs.
