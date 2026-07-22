# Building Ruby 3.3.10 (Linux / Windows / macOS) with GitHub Actions

This guide explains how to build Traveling Ruby **3.3.10** for Linux, Windows and
macOS using the repository's GitHub Actions workflows, including the changes
needed to ship the patched **OpenSSL 3.6.3** (fixes CVE-2026-9076 and other
3.6.0 vulnerabilities).

> **TL;DR**
> - **Windows** — works out of the box: run `win.yml`.
> - **Linux** — run `ubuntu-x86_64.yml` / `ubuntu-arm64.yml`. They now build the
>   OpenSSL-3.6.3 builder image on the runner (no registry needed).
> - **macOS** — needs an extra runtime-rebuild + re-point step (see the macOS
>   section); it is not a one-click build for the OpenSSL bump.

---

## Prerequisites

- Push access to this fork on GitHub.
- The [`gh` CLI](https://cli.github.com/) authenticated (`gh auth login`), or just
  use the **Actions** tab → *Run workflow* button in the browser.
- The branch containing the OpenSSL changes must be pushed to GitHub (workflows
  run from the ref you dispatch).

All the build workflows are triggered manually via `workflow_dispatch` and, by
default, build the full version matrix `3.2.9`, `3.3.10`, `3.4.7`. You download
the `3.3.10` artifact you care about — there is no need to narrow the matrix
(though you can; see [Building only 3.3.10](#building-only-3310)).

---

## Where OpenSSL comes from (important background)

OpenSSL is sourced differently on each platform, which is why the build steps
differ:

| Platform | OpenSSL source | To update it |
|---|---|---|
| **Linux** (glibc & musl) | Baked into the *builder Docker image* (`you54f/traveling-ruby-builder-*`), under `/hbb_shlib` | Rebuild the builder image with the patched `linux/image/install.sh` |
| **Windows** | Bundled inside the RubyInstaller download; overlaid with MSYS2 DLLs | Install `openssl` via MSYS2 and copy `libssl-3-x64.dll` / `libcrypto-3-x64.dll` over the bundled ones |
| **macOS** | Compiled into a *prebuilt runtime tarball* downloaded from a fixed release | Rebuild the runtime **and** re-point `scripts/download-macos-runtime.sh` at it |

The changes for all three are already committed to this branch:
- `linux/image/install.sh`, `linux-musl/image/install.sh` — build OpenSSL 3.6.3 into `/hbb_shlib`
- `.github/workflows/win.yml`, `windows/build-ruby.sh` — install + overlay MSYS2 OpenSSL DLLs
- `macos/setup-runtime.sh` — `OPENSSL_VERSION=3.6.3`
- `.github/workflows/ubuntu-x86_64.yml`, `ubuntu-arm64.yml` — build the builder image inline

---

## Linux

The Linux OpenSSL fix lives in the **builder Docker image**. The build workflow
normally *pulls* that image from Docker Hub (owned by upstream), which would give
you the old OpenSSL. To avoid needing any registry credentials, the workflows now
build the image **on the runner** first via a new step:

```yaml
- name: Build builder image (OpenSSL 3.6.3)
  run: |
      cd linux
      rake image
```

`rake image` only pulls the *public* Holy Build Box base image, then compiles
OpenSSL 3.6.3 (plus MySQL/PostgreSQL/ICU/libssh2) into it. No secrets required.

### Run it

```bash
# x86_64 (glibc)
gh workflow run ubuntu-x86_64.yml --ref <your-branch>

# arm64 (glibc)
gh workflow run ubuntu-arm64.yml --ref <your-branch>
```

Or use the **Actions** tab → select the workflow → **Run workflow** → pick your
branch.

### Expected runtime

~20–30 min extra for the one-time image build (OpenSSL + ICU compile), then the
Ruby build itself. This happens every run because the image is not cached between
runs. If you will rebuild Linux frequently, consider pushing the image to your own
registry once instead (see [Faster repeat Linux builds](#faster-repeat-linux-builds)).

### Verify OpenSSL

The build logs run `openssl version` inside the container (see
`linux/internal/build-ruby.sh`). Confirm it prints **`OpenSSL 3.6.3`**.

### musl / Alpine

`alpine-x86_64.yml` / `alpine-arm64.yml` build the musl variant. The
`linux-musl/image/install.sh` is already patched with OpenSSL 3.6.3, but note a
**pre-existing image-tag mismatch**: `linux-musl/Rakefile` builds tag
`4.0.0-alpine` while `alpine-*-image-builder.yml` pushes `4.0.0-linux-musl`. If
you need musl builds, reconcile those tags (and add an inline `rake image` step to
the alpine build workflows, mirroring the ubuntu ones) first.

---

## Windows

No changes needed to run — the fix is self-contained in the workflow:

- `win.yml` installs `openssl` via MSYS2 (`ruby/setup-ruby-pkgs`, `mingw:` list).
- `windows/build-ruby.sh` copies `libcrypto-3-x64.dll` and `libssl-3-x64.dll`
  from `/ucrt64/bin` over the RubyInstaller-bundled DLLs in `bin.real`.

### Run it

```bash
gh workflow run win.yml --ref <your-branch>
```

### Notes

- Ruby itself is a prebuilt RubyInstaller binary; we only replace the OpenSSL
  DLLs. This is safe because OpenSSL guarantees ABI compatibility across the 3.x
  series (3.6.0 → 3.6.3 is a patch bump). If MSYS2 has advanced past 3.6.x by
  build time, you'll get that newer 3.x version instead — also fine.
- The workflow caches the RubyInstaller archive and vendored gems, so repeat runs
  are fast.

---

## macOS

⚠️ **macOS is not a one-click OpenSSL update.** The `make-macos-*` job downloads a
**prebuilt runtime tarball** (which contains the compiled OpenSSL) from a fixed
release via `scripts/download-macos-runtime.sh`:

```
https://github.com/trubygems/traveling-ruby/releases/download/rel-20240201/macos-runtime-<arch>-gha.tar.gz
```

That tarball still has the old OpenSSL. Bumping `OPENSSL_VERSION` in
`macos/setup-runtime.sh` only affects the *runtime build*, not this download. To
actually ship OpenSSL 3.6.3 on macOS you must:

1. **Rebuild the runtime** with the clear-cache input, which compiles OpenSSL
   3.6.3 and uploads a `macos-runtime-<arch>-gha.tar.gz` artifact:
   ```bash
   gh workflow run macos-x86_64.yml --ref <your-branch> -f clear_cache=true
   gh workflow run macos-arm64.yml  --ref <your-branch> -f clear_cache=true
   ```
2. **Publish the new runtime tarball** to a release/location you control (e.g. a
   release on this fork), and **update the URL** in
   `scripts/download-macos-runtime.sh` to point at it.
3. Re-run the workflow normally so `make-macos-*` downloads the new runtime and
   builds Ruby against OpenSSL 3.6.3.

If you only need Linux + Windows, you can skip macOS entirely.

---

## Downloading the artifacts

Each workflow uploads a `traveling-ruby-<date>-3.3.10-<platform>-<arch>.tar.gz`
artifact. After a run completes:

```bash
# list recent runs to get the run id
gh run list --workflow ubuntu-x86_64.yml

# download all artifacts from a run into ./artifacts
gh run download <run-id> -D ./artifacts
```

Or download from the run's summary page in the **Actions** tab.

---

## Building only 3.3.10

By default the matrix builds `3.2.9`, `3.3.10`, `3.4.7` in parallel and you just
grab the 3.3.10 artifact. To build *only* 3.3.10 (faster, fewer runner minutes),
edit the `setup-ruby-versions` step in the relevant workflow:

```yaml
echo "ruby_versions=['3.3.10']" >> $GITHUB_OUTPUT
```

(Applies to `ubuntu-x86_64.yml`, `ubuntu-arm64.yml`, `macos-*.yml`; `win.yml`
lists versions directly in its `matrix.ruby-version`.)

---

## Faster repeat Linux builds

The inline `rake image` step rebuilds the OpenSSL image on every run (~20–30 min).
If you iterate often, build + push the image once to a registry you control and
have the build pull it instead:

1. Build and push (e.g. to GHCR):
   ```bash
   cd linux
   ARCHITECTURES=x86_64 rake image
   docker tag you54f/traveling-ruby-builder-x86_64:4.0.0-centos7 \
     ghcr.io/<org>/traveling-ruby-builder-x86_64:4.0.0-centos7-openssl363
   docker push ghcr.io/<org>/traveling-ruby-builder-x86_64:4.0.0-centos7-openssl363
   ```
2. Point the build at your tag (update the image reference in `linux/Rakefile`
   `IMAGE_VERSION` / image name) and remove the inline `rake image` step.

---

## Quick reference

| Platform | Command | OpenSSL 3.6.3 works out of the box? |
|---|---|---|
| Linux x86_64 | `gh workflow run ubuntu-x86_64.yml --ref <branch>` | ✅ (inline image build) |
| Linux arm64  | `gh workflow run ubuntu-arm64.yml --ref <branch>`  | ✅ (inline image build) |
| Linux musl   | `gh workflow run alpine-x86_64.yml --ref <branch>` | ⚠️ tag mismatch to fix first |
| Windows x86_64 | `gh workflow run win.yml --ref <branch>` | ✅ |
| macOS | `gh workflow run macos-x86_64.yml --ref <branch> -f clear_cache=true` + re-point runtime | ⚠️ multi-step |
