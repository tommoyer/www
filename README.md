# Hugo Site Docker Image

This repository builds a static site using [Hugo](https://gohugo.io/) and
serves it with [Nginx](https://nginx.org/). The Docker image supports
configurable Hugo build options so you can preview the generated site locally
before deploying it to production.

## Building the image

The Docker build exposes two build arguments:

- `HUGO_BASEURL` (default: `https://moyer.wtf/`)
- `HUGO_ENVIRONMENT` (default: `production`)

For production builds you can continue using the defaults:

```bash
docker build -t tommoyer/www .
```

To preview the content locally, override `HUGO_BASEURL` so that all generated
links match the address where you run the container:

```bash
docker build \
  --build-arg HUGO_BASEURL=http://localhost:8080 \
  --build-arg HUGO_ENVIRONMENT=development \
  -t tommoyer/www:local .
```

Then run the container and open `http://localhost:8080` in your browser:

```bash
docker run --rm -p 8080:8080 tommoyer/www:local
```

Because the base URL is injected during the build, the same Dockerfile can be
used both for local validation and for your Docker Swarm deployment without any
extra changes to the site configuration.

## Using Taskfile

If you use [go-task](https://taskfile.dev/) to manage local automation, the
included `Taskfile.yaml` provides shortcuts for the common Docker workflows
described above:

- `task build:prod` builds the production image with the default Hugo settings.
- `task build:local` builds a preview image with the base URL set to
  `http://localhost:8080` (override with `BASE_URL=...`) and the Hugo environment
  set to `development`.
- `task preview` depends on `build:local` and then runs the container locally,
  binding the preview to port 8080 (override with `PORT=...`).

These tasks mirror the manual commands while letting you tweak the image name,
base URL, or local port through Task variables as needed.
