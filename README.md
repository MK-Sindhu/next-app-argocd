# next-app: Next.js app with CI/CD and GitOps (Argo CD)

A Next.js todo app (`todo-app/`) that is built into a Docker image by GitHub Actions and deployed to Kubernetes by Argo CD.

## How it works

```
 git push (main)
      │
      ▼
 GitHub Actions (this repo)
   1. build the Docker image
   2. push mksindhu/argocd:<commit-sha> to Docker Hub
   3. clone MK-Sindhu/argo-deployment
   4. rewrite the image tag in manifest.yml, commit and push
      │
      ▼
 argo-deployment repo (desired state)
      │
      ▼
 Argo CD detects the change and syncs it to the cluster
```

This repo holds the application code and the CI pipeline. The `argo-deployment` repo holds the Kubernetes manifests that Argo CD watches.

## Repository layout

```
next-app/
├── .github/workflows/prod.yml   CI/CD pipeline
├── Dockerfile                   builds the app from todo-app/
├── .dockerignore                keeps node_modules, .next and .git out of the image
└── todo-app/                    the Next.js application
    ├── app/
    ├── public/
    └── package.json
```

## Run locally

Requires Node.js 20 or later.

```bash
cd todo-app
npm install
npm run dev        # http://localhost:3000
```

Production build:

```bash
npm run build
npm start
```

## Run with Docker

Build from the `next-app/` directory (the Dockerfile copies from `todo-app/`):

```bash
docker build -t mksindhu/argocd:local .
docker run --rm -p 3000:3000 mksindhu/argocd:local
```

## CI/CD pipeline

Defined in [.github/workflows/prod.yml](.github/workflows/prod.yml). It runs on every push to `main`.

| Step | What it does |
| --- | --- |
| Checkout | Fetches the repository |
| Docker login | Logs in to Docker Hub with `DOCKER_USERNAME` and `DOCKER_PASSWORD` |
| Buildx | Sets up the Docker build tooling |
| Build and push | Builds the image and pushes `mksindhu/argocd:<commit-sha>` |
| Update argo-deployment | Clones `argo-deployment` with `PAT`, replaces the image tag in `manifest.yml` with the new SHA, commits and pushes |

### Required GitHub secrets

Add these under Settings → Secrets and variables → Actions:

| Secret | Value |
| --- | --- |
| `DOCKER_USERNAME` | Docker Hub username |
| `DOCKER_PASSWORD` | Docker Hub access token with Read & Write permission (Docker Hub → Account Settings → Personal access tokens) |
| `PAT` | Fine-grained GitHub token with **Contents: Read and write** on `MK-Sindhu/argo-deployment` |

### Requirements on the argo-deployment repo

`manifest.yml` must contain an image line in this form, because the pipeline rewrites it with `sed`:

```yaml
image: mksindhu/argocd:<any-tag>
```

If the line is missing or uses a different image name, nothing changes and the workflow fails at the commit step ("nothing to commit").

## Deploying with Argo CD

1. Create a cluster and install Argo CD. See the top-level README in the parent folder; use `kubectl apply --server-side --force-conflicts` for the install manifest.
2. Create an Argo CD Application that points at the `argo-deployment` repo and the target namespace.
3. Enable auto-sync (and optionally prune and self-heal) so new image tags roll out without manual action.

## Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| `npm error ENOENT ... /app/package.json` during Docker build | The Dockerfile must copy from `todo-app/`, where `package.json` lives. Build from `next-app/`. |
| Docker push fails with an invalid reference | Image repository names must be lowercase. |
| `403` when pushing to `argo-deployment` | `PAT` is missing, expired, or not scoped to `argo-deployment` with Contents read and write. `GITHUB_TOKEN` cannot write to other repos. |
| `nothing to commit, working tree clean` in the last step | The `sed` pattern did not match. Check that `manifest.yml` contains `image: mksindhu/argocd:...`. |
| Workflow never runs | The folder must be `.github/workflows/` (plural) at the repository root, and the push must be to `main`. |
