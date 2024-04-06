FROM you54f/holy-build-box:alpine
ADD . /tr_build
RUN env ARCHITECTURE=$(uname -m) env SKIP_INITIALIZE=false /tr_build/install.sh
RUN env ARCHITECTURE=$(uname -m) env SKIP_MYSQL=false /tr_build/install.sh
RUN env ARCHITECTURE=$(uname -m) env SKIP_POSTGRESQL=false /tr_build/install.sh
RUN env ARCHITECTURE=$(uname -m) env SKIP_ICU=false /tr_build/install.sh
RUN env ARCHITECTURE=$(uname -m) env SKIP_LIBSSH2=false /tr_build/install.sh
RUN env ARCHITECTURE=$(uname -m) env SKIP_LIBYAML=false /tr_build/install.sh
RUN env ARCHITECTURE=$(uname -m) env SKIP_LIBFFI=false /tr_build/install.sh
RUN env ARCHITECTURE=$(uname -m) env SKIP_CLEANUP=false /tr_build/install.sh