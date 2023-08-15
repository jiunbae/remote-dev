#!/bin/bash
# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

set -e

# start ssh
service ssh start

# default args
NOTEBOOK_ARGS=${NOTEBOOK_ARGS:-}
CODE_SERVER_ARGS="--disable-telemetry ${CODE_SERVER_ARGS}"

# add certification key path if cert file exists
if [[ -f "${CERT_FILE}" && -f "${KEY_FILE}" ]]; then
    NOTEBOOK_ARGS="--certfile=${CERT_FILE} ${NOTEBOOK_ARGS}"
    NOTEBOOK_ARGS="--keyfile=${KEY_FILE} ${NOTEBOOK_ARGS}"

    mkdir -p ${HOME}/.local/share/code-server
    rm -f ${HOME}/.local/share/code-server/localhost.crt
    ln -s ${CERT_FILE} ${HOME}/.local/share/code-server/localhost.crt
    rm -f ${HOME}/.local/share/code-server/localhost.key
    ln -s ${KEY_FILE} ${HOME}/.local/share/code-server/localhost.key
    CODE_SERVER_ARGS="--cert ${CODE_SERVER_ARGS}"
fi

# set jupyter password
if [[ "${PASSWORD}" ]]; then
    salt=$(openssl rand -hex 6)
    algorithm=sha1
    HASHED_PASSWORD=$(echo -n "$(echo ${PASSWORD} \
        | iconv -t utf-8)${salt}" \
        | openssl dgst -${algorithm} \
        | awk -v alg="${algorithm}" -v salt="${salt}" '{print alg ":" salt ":" $NF}')

    echo "c.NotebookApp.password = '${HASHED_PASSWORD}'" >> ${HOME}/.jupyter/jupyter_server_config.py
fi

# add default NOTEBOOK_ARGS
if [[ "${NOTEBOOK_ARGS} $*" != *"--allow-root "* ]]; then
    NOTEBOOK_ARGS="--allow-root ${NOTEBOOK_ARGS}"
fi

if [[ "${NOTEBOOK_ARGS} $*" != *"--no-browser "* ]]; then
    NOTEBOOK_ARGS="--no-browser ${NOTEBOOK_ARGS}"
fi

if [[ "${NOTEBOOK_ARGS} $*" != *"--ip="* ]]; then
    NOTEBOOK_ARGS="--ip=0.0.0.0 ${NOTEBOOK_ARGS}"
fi

# run jupyter
exec jupyter lab ${NOTEBOOK_ARGS} "$@" &

# add default CODE_SERVER_ARGS

if [[ "${CODE_SERVER_ARGS} $*" != *"--bind-addr "* ]]; then
    CODE_SERVER_ARGS="--bind-addr=0.0.0.0:${CODE_SERVER_PORT} ${CODE_SERVER_ARGS}"
fi

if [[ "${CODE_SERVER_ARGS} $*" != *"--user-data-dir "* ]]; then
    CODE_SERVER_ARGS="--user-data-dir ${CODE_SERVER_HOME}/config/data ${CODE_SERVER_ARGS}"
fi

if [[ "${CODE_SERVER_ARGS} $*" != *"--extensions-dir "* ]]; then
    CODE_SERVER_ARGS="--extensions-dir ${CODE_SERVER_HOME}/config/extensions ${CODE_SERVER_ARGS}"
fi

# run code-server
exec ${CODE_SERVER_HOME}/bin/code-server \
    ${CODE_SERVER_ARGS} \
    --auth password \
    "${WORKSPACE}" &

# Wait for any process to exit
wait -n

# Exit with status of process that exited first
exit $?
