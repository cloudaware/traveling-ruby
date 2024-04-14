# TODO

Just some WIP notes to keep some track of testing progress

### Latest Ruby Versions

- `3.3.0`
- `3.2.3`
- `3.1.4`
- `3.0.6`
- `2.6.10`

#### Ruby Build Caveats

- 3.0.x and below builds require openssl 1.1.1
  - Set `OPENSSL_1_1_LEGACY` to build OpenSSL 1.1.1 for macos.
- Linux 2.6.10 - Requires bundler version 2.4.x (latest 2.4.22 at time of writing)

### Ruby Versions failing to build

- Linux  `3.0.5` / `3.0.6`
  - OpenSSL not found error (when using OpenSSL 3.2 or OpenSSL 1.1.1)
 - Linux  `2.7.8`
  - OpenSSL gem fails to build 
- MacOS  `2.6.10` / `2.7.8`

### Gems failing testing

- `test-unit`
  - MacOS
  - Linux

- `debug`
  - Ruby `3.0.x`

## Native Extensions

Currently `sqlite` and `nokogiri` provide native extensions in the 2nd format, where our guides/installers consider the first

- output/3.2.3-arm64/lib/ruby/gems/3.2.0/extensions/aarch64-linux/3.2.0-static/bcrypt-3.1.18/bcrypt_ext.so
  
We delete the version numbers, other than the version of ruby we are packaging, but we dont package up the extension

- output/3.2.3-arm64/lib/ruby/gems/3.2.0/gems/sqlite3-1.6.3-aarch64-linux/lib/sqlite3/3.2/sqlite3_native.so
- output/3.2.3-arm64/lib/ruby/gems/3.2.0/gems/sqlite3-1.6.3-aarch64-linux/lib/sqlite3/3.1/sqlite3_native.so
- output/3.2.3-arm64/lib/ruby/gems/3.2.0/gems/sqlite3-1.6.3-aarch64-linux/lib/sqlite3/3.0/sqlite3_native.so
- output/3.2.3-arm64/lib/ruby/gems/3.2.0/gems/sqlite3-1.6.3-aarch64-linux/lib/sqlite3/2.7/sqlite3_native.so

should we create a full fat bundler, that has all the gem extensions pre-installed?

- Now created as `-full` packages (Linux/MacOS only)

## Traveling Ruby Supported Platforms

### Linux

| Platform                 | Architecture  | Musl | Glibc
|--------------------------|---------------|------|-------
| ARMv8 64-bit (`arm64v8`) | ARMv8         |  ✅  | ✅
| Linux x86-64 (`amd64`)   | x86-64        |  ✅  | 🚧
| x86/i686 (`i386`)        | x86/i686      |  ✅  | 🚧
| IBM z Systems (`s390x`)  | z Systems     |  ✅  | 🚧
| IBM POWER8 (`ppc64le`)   | POWER8        |  ✅  | 🚧

- Alpine images built against 3.15
- Ubuntu images built against 14.04 (glibc 2.19)
- Centos based packages built against Centos7 (glibc 2.17)

## MacOS

| Platform                 | Architecture  | Supported
|--------------------------|---------------|------
| MacOS x86-64 (`darwin-x86_64`) | x86-64 |  ✅  
| MacOS arm64 (`darwin-arm64`)   | arm64     |  ✅

- macos x86_64 binaries - 10.15 Catalina onwards
- macos arm64 binaries - 11.0 Big Sur onwards

## Windows

| Platform                 | Architecture  | Supported
|--------------------------|---------------|------
| Windows x86-64 (`windows-x86_64`) | x86-64 |  ✅  
| Windows x86 (`windows-x86`)   | x86     |  ✅
| Windows arm64 (`windows-arm64`)   | arm64     |  🚧

- windows-arm64, ruby 3.1.4 only

- 🚧 Native extensions not currently supported
  - Use ocran or aibika (forks of ocran) to build native extensions
- Docker Support
  - Nanoserver images, will work if libgmp from package is copied to C:\Windows\System32
- Wine support
  - x86_64 package fails on darwin-arm64 with unexpected ucrtbase.dll error
    - Workaround, use x86 package on darwin-arm64
- Windows VM support
  - x86_64 package fails when emulated in vm's on darwin-arm64 with unexpected ucrtbase.dll error
    - Workaround, use x86 package on darwin-arm64
    - Workaround, use arm64 package on darwin-arm64

## Snapshot releases

- https://www.ruby-lang.org/en/downloads/
- https://cache.ruby-lang.org/pub/ruby/snapshot/snapshot-ruby_3_3.tar.gz
- `snapshot-ruby_3_3`
- `snapshot-master`

- Windows
  - `rubyinstaller-head`