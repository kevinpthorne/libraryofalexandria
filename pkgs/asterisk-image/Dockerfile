FROM andrius/asterisk:22

RUN apt-get update && apt-get install -y --no-install-recommends \
    odbc-postgresql \
    unixodbc \
    libpq5 \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /usr/lib/odbc \
    && ln -sf /usr/lib/*/odbc/psqlodbcw.so /usr/lib/odbc/psqlodbcw.so \
    && ln -sf /usr/lib/*/odbc/libodbcpsqlS.so /usr/lib/odbc/libodbcpsqlS.so



