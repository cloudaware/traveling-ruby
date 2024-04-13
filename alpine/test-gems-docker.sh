#!/usr/bin/env bash
set -e

SELFDIR=`dirname "$0"`
SELFDIR=`cd "$SELFDIR" && pwd`

if [ -z "$1" ]; then
    echo "Usage: $0 output/<ruby-version>-<arch> <image>"
    echo "example: $0 3.2.3-arm64"
    echo "image: alpine:3.15"
    echo "image is optional|default: alpine:3.15"
    exit 1
fi
IMAGE=${2:-"alpine:3.15"}
if ! command -v docker &> /dev/null
then
        echo "Error: docker could not be found"
        exit 1
fi

ARCH=$(echo $1 | sed -E 's/output\///' | sed 's/.*-//')
RUBY_VERSION=$(echo $1  | sed -E 's/(-arm64|-x86_64)//' | sed -E 's/output\///')
echo "ARCH: $ARCH"
echo "RUBY_VERSION: $RUBY_VERSION"

# ## override for docker platform
[ "$ARCH" == "x86_64" ] && ARCH="amd64"
[ "$ARCH" == "riscv64" ] && IMAGE="riscv64/alpine:20210804"
# note libgcc is required for alpine vanilla images
# cp /usr/lib/libgcc_s.so.1 /app  
echo docker run --platform linux/"${ARCH}" --rm --entrypoint /bin/sh -v $SELFDIR/..:/home "${IMAGE}" -c "apk add bash && ./home/shared/test-gems.sh home/alpine/"$@"";

docker run --platform linux/"${ARCH}" --rm --entrypoint /bin/sh -v $SELFDIR/..:/home "${IMAGE}" -c "apk add bash && ./home/shared/test-gems.sh home/alpine/"$@"";
