#!/usr/bin/env bash
set -e

source pipe-tools-utils
THIS_SCRIPT_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )"
ASSETS=${THIS_SCRIPT_DIR}/../assets
source ${THIS_SCRIPT_DIR}/pipeline.sh

PROCESS=$(basename $0 .sh)
ARGS=( DT \
  SOURCE \
  DEST \
  TEMP_TABLE )

echo -e "\nRunning:\n${PROCESS}.sh $@ \n"

display_usage() {
  echo -e "\nUsage:\n${PROCESS}.sh ${ARGS[*]}\n"
  echo -e "DT: The date expressed with the following format YYYY-MM-DD.\n"
  echo -e "SOURCE: The GCP bucket where csv source files are located (Format expected gs://the-gcp-bucket/some-folder ).\n"
  echo -e "DEST: Table id where place the results (Format expected PROJECT:DATASET.TABLE).\n"
  echo -e "TEMP_TABLE: Temp table id where place the results temporarily (Format expected DATASET.TABLE).\n"
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

################################################################################
# Loads the VMS DATA into a temp table
################################################################################
echo
echo "Loads the VMS DATA into a temp table"
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

if [ "$?" -ne 0 ]; then
  echo "  Could not find a position's report csv file for the given day on ${GCS_SOURCE}."
  exit 1
fi

echo "CSV File ${GCS_SOURCE}"

bq load \
  --replace \
  --source_format=CSV \
  -F=";" \
  --autodetect \
  --schema=${SCHEMA} \
  ${TEMP_TABLE} \
  ${GCS_SOURCE}
if [ "$?" -ne 0 ]; then
  echo "  Unable to load the VMS DATA."
  display_usage
  exit 1
fi


################################################################################
# Loads the VMS DATA into the raw table
################################################################################
# By default use the latest temp raw schema valid since 2022
echo
echo "Loads the VMS DATA into the RAW table"
SQL=${ASSETS}/load_raw_data.sql.j2
if [[ $(($YEAR)) -eq 2021 ]]; then
  SQL=${ASSETS}/load_raw_data.2021.sql.j2
fi
if [[ $(($YEAR)) -le 2020 ]]; then
  SQL=${ASSETS}/load_raw_data.2011-2020.sql.j2
fi
PARTITION=`echo "${DATE}" | sed -r 's#-##g'`

jinja2 ${SQL} \
  -D source=${TEMP_TABLE} \
  -D date=${DT} \
  | bq query -q --max_rows=0 --allow_large_results \
    --replace \
    --nouse_legacy_sql \
    --destination_schema ${ASSETS}/raw_schema.json \
    --destination_table ${DEST} \


#############################################################
# Updates the table description.
#############################################################
echo "Updating table description ${DEST}"
TABLE_DESC=(
  "* Pipeline: ${PIPELINE} ${PIPELINE_VERSION}"
  "* Source: VMS ${SOURCE}"
  "* Command:"
  "$(basename $0)"
  "$@"
)
TABLE_DESC=$( IFS=$'\n'; echo "${TABLE_DESC[*]}" )

echo "${TABLE_DESC}"
bq update --description "${TABLE_DESC}" ${DEST}

if [ "$?" -ne 0 ]; then
  echo "  Unable to update the normalize table decription ${DEST}"
  display_usage
  exit 1
fi

echo "${DEST} Done."
