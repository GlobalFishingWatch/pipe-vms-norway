#!/usr/bin/env bash

THIS_SCRIPT_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )"

display_usage() {
  echo "Available Commands"
  echo "  fetch_vms_data         Download NORWAY VMS data to GCS"
  echo "  fetch_vms_logbook      Download NORWAY VMS logbook to GCS"
  echo "  load_vms_data_to_bq    Load NORWAY VMS data into BQ"
  echo "  fetch_normalized_vms   Copy and normalize vms data."
}


if [[ $# -le 0 ]]
then
    display_usage
    exit 1
fi

case $1 in

  fetch_normalized_vms)
    xdaterange ${THIS_SCRIPT_DIR}/fetch_normalized_vms.sh "${@:2}"
    ;;

  fetch_vms_data)
    ${THIS_SCRIPT_DIR}/fetch_vms_data.sh "${@:2}"
    ;;

  load_vms_data_to_bq)
    ${THIS_SCRIPT_DIR}/load_vms_data_to_bq.sh "${@:2}"
    ;;

  fetch_vms_logbook)
    ${THIS_SCRIPT_DIR}/fetch_vms_logbook.sh "${@:2}"
    ;;

  *)
    display_usage
    exit 1
    ;;
esac
