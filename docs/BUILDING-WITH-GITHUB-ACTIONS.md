# Building Ruby 3.3.10 (Linux / Windows / macOS) with GitHub Actions

Build Traveling Ruby with the patched **OpenSSL 3.6.3** via the repo's workflows.

## Quick start

Manual runs default to **Ruby 3.3.10 only, no gems**. Trigger from the Actions
tab (*Run workflow*) or with `gh`:

```bash
gh workflow run ubuntu-x86_64.yml --ref <branch>   # Linux glibc x86_64
gh workflow run ubuntu-arm64.yml  --ref <branch>   # Linux glibc arm64
gh workflow run win.yml           --ref <branch>   # Windows x86_64
gh workflow run macos-x86_64.yml  --ref <branch>   # macOS x86_64
gh workflow run macos-arm64.yml   --ref <branch>   # macOS arm64
```

Download the artifact when done:

```bash
gh run download <run-id> -D ./artifacts   # -> traveling-ruby-<date>-3.3.10-<platform>-<arch>.tar.gz
```

## Inputs (manual runs)

| Input | Default | Effect |
|---|---|---|
| `ruby_version` | `3.3.10` | Single version to build. Blank = full default matrix (`3.2.9 3.3.10 3.4.7`). |
| `build_gems` | `false` | `false` = plain Ruby only (skips compiling/packaging the ~50 native gems, and gem tests). `true` = full package. |

```bash
gh workflow run win.yml --ref <branch> -f ruby_version=3.3.10 -f build_gems=false
```

Push/release runs are unchanged: full matrix, with gems.

## Verify OpenSSL

```bash
ruby -ropenssl -e 'puts OpenSSL::OPENSSL_VERSION'          # compile-time
ruby -ropenssl -e 'puts OpenSSL::OPENSSL_LIBRARY_VERSION'  # runtime DLL/lib
```
Both should report `3.6.3`.

## How OpenSSL 3.6.3 gets in (per platform)

- **Linux** — the builder Docker image compiles OpenSSL 3.6.3 into `/hbb_shlib`
  (`linux/image/install.sh`) and Ruby links it statically. The build workflow
  builds that image inline (`rake image`), so no registry is needed.
- **Windows** — RubyInstaller ships OpenSSL 3.6.0, so the build: (1) updates
  MSYS2 to OpenSSL 3.6.3, (2) rebuilds the `openssl` extension against it so
  `OPENSSL_VERSION` reads 3.6.3, and (3) overwrites the `libssl`/`libcrypto`
  DLLs in **both** `bin.real/` **and** `bin.real/ruby_builtin_dlls/` (Ruby loads
  runtime DLLs from the latter) so `OPENSSL_LIBRARY_VERSION` reads 3.6.3.
- **macOS** — the `package-runtime` job builds a runtime with OpenSSL 3.6.3
  (`macos/setup-runtime.sh`) and uploads it; the build job downloads that
  artifact instead of the old pinned runtime.

## Notes

- **macOS** rebuilds the runtime every run (slow; macOS runner minutes are
  costly).
- **arm64 / musl (Alpine)**: `ubuntu-arm64` is wired for the inputs; the
  `alpine-*` workflows are not, and have a pre-existing builder image tag
  mismatch to resolve before use.
- All build workflows are `workflow_dispatch`-only (auto push/PR triggers are
  commented out).
