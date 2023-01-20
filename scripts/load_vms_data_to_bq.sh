#!/usr/bin/env bash
set -e

source pipe-tools-utils
THIS_SCRIPT_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )"
ASSETS=${THIS_SCRIPT_DIR}/../assets
source ${THIS_SCRIPT_DIR}/pipeline.sh

PROCESS=$(basename $0 .sh)
ARGS=( SOURCE \
  DEST \
  TEMP_TABLE \
  DT )

echo -e "\nRunning:\n${PROCESS}.sh $@ \n"

display_usage() {
  echo -e "\nUsage:\n${PROCESS}.sh ${ARGS[*]}\n"
  echo -e "SOURCE: The table id where is the source table (Format expected PROJECT:DATASET.TABLE).\n"
  echo -e "DEST: Table id where place the results (Format expected PROJECT:DATASET.TABLE).\n"
  echo -e "TEMP_TABLE: Temp table id where place the results temporarily (Format expected DATASET.TABLE).\n"
  echo -e "DT: The date expressed with the following format YYYY-MM-DD.\n"
}

if [[ $# -ne ${#ARGS[@]} ]]
then
    display_usage
    exit 1
fi

ARG_VALUES=("$@")
for index in ${!ARGS[*]}; do
  echo "${ARGS[$index]}=${ARG_VALUES[$index]}"
  declare "${ARGS[$index]}"="${ARG_VALUES[$index]}"
done

YEAR=${DT:0:4}

SCHEMA=''
if [[ $(($YEAR)) -ge 2022 ]]; then
  SCHEMA="${ASSETS}/temp_raw_schema.json"
fi
if [[ $(($YEAR)) -eq 2021 ]]; then
  SCHEMA="${ASSETS}/temp_raw_schema.2021.json"
fi
if [[ $(($YEAR)) -le 2020 ]]; then
  SCHEMA="${ASSETS}/temp_raw_schema.2011-2020.json"
fi
################################################################################
# Loads the VMS DATA
################################################################################
echo
echo "Loads the VMS DATA"
# By default use the latest temp raw schema valid since 2022
SCHEMA=${ASSETS}/temp_raw_schema.json
if [[ $(($YEAR)) -eq 2021 ]]; then
  SCHEMA="${ASSETS}/temp_raw_schema.2021.json"
fi
if [[ $(($YEAR)) -le 2020 ]]; then
  SCHEMA="${ASSETS}/temp_raw_schema.2011-2020.json"
fi
# Get the most recent gzip file in the folder
response=(`gsutil ls -l ${SOURCE}/${DT}/* | sort -k 2 | tail -n 2 | head -1`)
GCS_SOURCE=${response[2]}
bq load \
  --replace \
  --source_format=CSV \
  --time_partitioning_type=DAY \
  --time_partitioning_field=timestamp_utc  \
  -F=";" \
  --autodetect \
  --schema=${SCHEMA} \
  ${TEMP_TABLE} \
  ${GCS_SOURCE}
if [ "$?" -ne 0 ]; then
  echo "  Unable to load the VMS DATA
."
  display_usage
  exit 1
fi

#############################################################
# Updates the table description.
#############################################################
echo "Updating table description ${DEST_TABLE}"
TABLE_DESC=(
  "* Pipeline: ${PIPELINE} ${PIPELINE_VERSION}"
  "* Source: VMS ${SOURCE_TABLE}"
  "* Command:"
  "$(basename $0)"
  "$@"
)
TABLE_DESC=$( IFS=$'\n'; echo "${TABLE_DESC[*]}" )

echo "${TABLE_DESC}"
bq update --description "${TABLE_DESC}" ${DEST_TABLE}

if [ "$?" -ne 0 ]; then
  echo "  Unable to update the normalize table decription ${DEST_TABLE}"
  display_usage
  exit 1
fi

echo "${DEST_TABLE} Done."
