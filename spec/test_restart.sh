#!/bin/bash

set -e
set -o nounset

WORKDIR="$(mktemp)"
PIDFILE="${WORKDIR}/resqued.pid"
CONFIG="${WORKDIR}/config.rb"

# mktemp makes a file, but we want a dir.
rm -f "$WORKDIR"
mkdir "$WORKDIR"

set -x
cd "$(dirname "$0")/.."

main() {
  trap cleanup EXIT

  configure_resqued
  start_resqued
  restart_resqued
  stop_resqued
}

configure_resqued() {
  # Don't configure any workers. That way, we don't need to have redis running.
  touch "${CONFIG}"
}

start_resqued() {
  bin_resqued=bin/resqued
  if [ -x gemfiles/bin/resqued ]; then
    bin_resqued=gemfiles/bin/resqued
  fi
  $bin_resqued --pidfile "${PIDFILE}" "${CONFIG}" &
  sleep 1
  echo expect to find the master process and the first listener
  running # set -e will make the test fail if it's not running
  ps axo pid,args | grep [r]esqued-
  ps axo pid,args | grep [r]esqued- | grep -q 'listener #1.*running'
}

restart_resqued() {
  local pid="$(cat "${PIDFILE}")"
  kill -HUP "$pid"
  sleep 1
  echo expect to find the master process and the second listener
  running
  ps axo pid,args | grep [r]esqued-
  ps axo pid,args | grep [r]esqued- | grep -qv 'listener #1'
  ps axo pid,args | grep [r]esqued- | grep -q 'listener #2.*running'
}

stop_resqued() {
  local pid="$(cat "${PIDFILE}")"
  kill -TERM "$pid"
  sleep 1
  echo expect everything to be stopped
  if running >&/dev/null; then
    echo "expected resqued to be stopped"
    false
  fi
  ps axo pid,args | grep [r]esqued- || true
  test -z "$(ps axo pid,args | grep [r]esqued-)"
}

running() {
  set -e
  test -f "${PIDFILE}"
  local pid="$(cat "${PIDFILE}")"
  kill -0 "$pid"
  ps o pid,args "$pid"
}

cleanup() {
  while running >&/dev/null; do
    kill -TERM "$(cat "${PIDFILE}")"
    sleep 2
  done
  rm -rfv "${WORKDIR}" || rm -rf "${WORKDIR}"
}

main
