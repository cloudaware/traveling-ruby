FROM you54f/holy-build-box:ubuntu
# ADD . /tr_build
ADD functions.sh /tr_build/functions.sh
ADD 01_INITIALIZE.sh /tr_build/01_INITIALIZE.sh
RUN env ARCHITECTURE=$(uname -m) env SKIP_INITIALIZE=false /tr_build/01_INITIALIZE.sh
ADD 02_MYSQL.sh /tr_build/02_MYSQL.sh
RUN env ARCHITECTURE=$(uname -m) env SKIP_MYSQL=false /tr_build/02_MYSQL.sh
ADD 03_POSTGRESQL.sh /tr_build/03_POSTGRESQL.sh
RUN env ARCHITECTURE=$(uname -m) env SKIP_POSTGRESQL=false /tr_build/03_POSTGRESQL.sh
ADD 04_ICU.sh /tr_build/04_ICU.sh
RUN env ARCHITECTURE=$(uname -m) env SKIP_ICU=false /tr_build/04_ICU.sh
ADD 05_LIBSSH2.sh /tr_build/05_LIBSSH2.sh
RUN env ARCHITECTURE=$(uname -m) env SKIP_LIBSSH2=false /tr_build/05_LIBSSH2.sh
ADD 06_LIBYAML.sh /tr_build/06_LIBYAML.sh
RUN env ARCHITECTURE=$(uname -m) env SKIP_LIBYAML=false /tr_build/06_LIBYAML.sh
ADD 07_LIBFFI.sh /tr_build/07_LIBFFI.sh
RUN env ARCHITECTURE=$(uname -m) env SKIP_LIBFFI=false /tr_build/07_LIBFFI.sh
ADD 08_CLEANUP.sh /tr_build/08_CLEANUP.sh
RUN env ARCHITECTURE=$(uname -m) env SKIP_CLEANUP=false /tr_build/08_CLEANUP.sh