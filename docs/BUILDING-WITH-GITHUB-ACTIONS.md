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

All the build workflows are triggered manually via `workflow_dispatch`. When you
dispatch them manually they build **only Ruby 3.3.10** and **skip native gems**
by default (see below). Automatic runs (push / release) keep the old behaviour:
the full `3.2.9 / 3.3.10 / 3.4.7` matrix with gems.

### Manual run inputs (build 3.3.10 only, no gems)

The `x86_64` workflows (`ubuntu-x86_64.yml`, `win.yml`, `macos-x86_64.yml`) expose
two `workflow_dispatch` inputs:

| Input | Default | Meaning |
|---|---|---|
| `ruby_version` | `3.3.10` | Single Ruby version to build. Leave blank to build all default versions. |
| `build_gems` | `false` | When `false`, only the plain Ruby binary is built — the ~50 native gems (puma, rugged, nokogiri, mysql2, pg…) are **not** compiled or packaged, and the gem test/`*-full.tar.gz` steps are skipped. Set `true` to build the full package. |

So a default manual run gives you exactly one artifact per platform:
`traveling-ruby-20251122-3.3.10-<platform>-x86_64.tar.gz` (Ruby only).

How the toggle works under the hood: the input sets a `SKIP_GEMS` env var that the
build scripts honour (`linux/internal/build-ruby.sh`, `macos/build-ruby.sh`,
`windows/build-ruby.sh`), and gates the gem packaging/test steps in the workflows.

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
# x86_64 (glibc) — Ruby 3.3.10 only, no gems (defaults)
gh workflow run ubuntu-x86_64.yml --ref <your-branch>

# explicit form / to build gems too
gh workflow run ubuntu-x86_64.yml --ref <your-branch> \
  -f ruby_version=3.3.10 -f build_gems=false
```

Or use the **Actions** tab → select the workflow → **Run workflow** → pick your
branch and inputs.

> `ubuntu-arm64.yml` builds arm64 but has **not** been wired with the
> `ruby_version` / `build_gems` inputs yet — it still builds the full matrix with
> gems. Ask if you want arm64 (and musl) wired the same way.

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
# Ruby 3.3.10 only, no gems (defaults)
gh workflow run win.yml --ref <your-branch>

# explicit / with gems
gh workflow run win.yml --ref <your-branch> \
  -f ruby_version=3.3.10 -f build_gems=false
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
   gh workflow run macos-x86_64.yml --ref <your-branch> \
     -f clear_cache=true -f ruby_version=3.3.10 -f build_gems=false
   ```
   (`macos-arm64.yml` is not yet wired with the `ruby_version`/`build_gems`
   inputs.)
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

## Building a different version / all versions

Manual runs default to `ruby_version=3.3.10`. To build a different single version,
pass `-f ruby_version=3.4.7`. To build the full default matrix in a manual run,
pass an empty value: `-f ruby_version=`.

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

All manual runs below build **Ruby 3.3.10 only, no gems** by default.

| Platform | Command | OpenSSL 3.6.3 works out of the box? |
|---|---|---|
| Linux x86_64 | `gh workflow run ubuntu-x86_64.yml --ref <branch>` | ✅ (inline image build) |
| Windows x86_64 | `gh workflow run win.yml --ref <branch>` | ✅ |
| macOS x86_64 | `gh workflow run macos-x86_64.yml --ref <branch> -f clear_cache=true` + re-point runtime | ⚠️ multi-step |
| Linux arm64  | `gh workflow run ubuntu-arm64.yml --ref <branch>`  | ✅ build, but ⚠️ not wired for version/gems inputs |
| Linux musl   | `gh workflow run alpine-x86_64.yml --ref <branch>` | ⚠️ tag mismatch + not wired |
