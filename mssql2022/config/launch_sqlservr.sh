#!/bin/bash

# Work around mssql-docker#968 while preserving the setup performed by the
# image's launch_sqlservr.sh. The upstream script backgrounds sqlservr but
# does not forward container stop signals to it.

permissions_check_path="/opt/mssql/bin/permissions_check.sh"

if [[ -x "$permissions_check_path" ]]; then
    "$permissions_check_path" || exit $?
else
    echo "Unable to run startup permissions check, exiting." >&2
    exit 1
fi

case "${MSSQL_PID,,}" in
    standarddeveloper)
        export MSSQL_PID="DeveloperStandard"
        ;;
    enterprisedeveloper)
        export MSSQL_PID="Developer"
        ;;
esac

source /opt/mssql/bin/init_custom_setup.sh || exit $?

"$@" &
sqlservr_pid=$!

forward_signal() {
    local signal="$1"
    local status

    trap - TERM INT
    kill "-$signal" "$sqlservr_pid" 2>/dev/null || true
    wait "$sqlservr_pid"
    status=$?
    exit "$status"
}

trap 'forward_signal TERM' TERM
trap 'forward_signal INT' INT

/opt/mssql/bin/run_custom_setup.sh || {
    status=$?
    kill -TERM "$sqlservr_pid" 2>/dev/null || true
    wait "$sqlservr_pid" 2>/dev/null || true
    exit "$status"
}

wait "$sqlservr_pid"
