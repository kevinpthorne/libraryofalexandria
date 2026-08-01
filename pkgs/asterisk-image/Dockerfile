FROM andrius/asterisk:22

RUN apt-get update && apt-get install -y --no-install-recommends \
    odbc-postgresql \
    unixodbc \
    && rm -rf /var/lib/apt/lists/*
