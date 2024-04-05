FROM you54f/holy-build-box:3.1.0-i386-alpine
# FROM you54f/holy-build-box:3.1.0-s390x-alpine
# FROM you54f/holy-build-box:3.1.0-arm-v6-alpine
# FROM you54f/holy-build-box:3.1.0-amd64-alpine
# FROM you54f/holy-build-box:3.1.0-ppc64le-alpine
ADD . /tr_build
# RUN apk --no-cache add bash
RUN env ARCHITECTURE=$(uname -m) env SKIP_INITIALIZE=false /tr_build/install.sh
RUN env ARCHITECTURE=$(uname -m) env SKIP_MYSQL=false /tr_build/install.sh
RUN env ARCHITECTURE=$(uname -m) env SKIP_POSTGRESQL=false /tr_build/install.sh
RUN env ARCHITECTURE=$(uname -m) env SKIP_ICU=false /tr_build/install.sh
RUN env ARCHITECTURE=$(uname -m) env SKIP_LIBSSH2=false /tr_build/install.sh
RUN env ARCHITECTURE=$(uname -m) env SKIP_LIBYAML=false /tr_build/install.sh
RUN env ARCHITECTURE=$(uname -m) env SKIP_LIBFFI=false /tr_build/install.sh
RUN env ARCHITECTURE=$(uname -m) env SKIP_CLEANUP=false /tr_build/install.sh