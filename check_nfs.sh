#!/bin/bash

set -x
timeout=2
output='-1'
exit_code=0

function usage {
  echo "$0 path"
  exit 2
}

function is_readonly {
  local fs="$1"
  local options="$(grep "${fs}" /proc/mounts | cut -d' ' -f4)"
  while read opt; do
    if [[ "$opt" == 'ro' ]]; then
      return 0
    fi
  done <<< $(echo "$options" | tr ',' '\n')
  return 1
}

function get_latency {
  local output='-1'
  local fs="$1"
  local results="$2"

  ioping -c5 -i 1ms -B "$fs" > "${results}" &
  local run_pid="$!"
  
  for (( i=0; i<${timeout}; ++i )); do
    if ps -p ${run_pid} &>/dev/null; then
      sleep 1
    else
      break
    fi
    echo "i=$i"
  done
  
  if ps -p ${run_pid} &>/dev/null; then
     kill ${run_pid}
     kill -9 ${run_pid}
     output="-1"
  else
     output="$(tail -1 $results)"
  fi
  echo "$output"
}

function get_ls {
  local output='-1'
  local fs="$1"
  local results="$2"

  ls -a1 "${fs}" > "${results}" &
  local run_pid="$!"
  
  for (( i=0; i<${timeout}; ++i )); do
    if ps -p ${run_pid} &>/dev/null; then
      sleep 1
    else
      break
    fi
    echo "i=$i"
  done
  
  if ps -p ${run_pid} &>/dev/null; then
     kill ${run_pid}
     kill -9 ${run_pid}
     output="-1"
  else
     output="$(wc -l $results)"
  fi
  echo "$output"
}

function cleanup {
  retval=$?
  test -e "${results}" && rm "${results}"
  exit ${retval}
}

trap cleanup EXIT INT TERM


if [ -z "$1" ] ; then #|| [ ! -d "$1" ]; then
   usage
fi

fs="$1"
results="$(mktemp)"

if is_readonly "${fs}" ; then
  output=$(get_ls "${fs}" "${results}")
else
  output=$(get_latency "${fs}" "${results}")
fi

echo "${output}"
