#!/usr/bin/env bash
set -e

source pipe-tools-utils
THIS_SCRIPT_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )"
ASSETS=${THIS_SCRIPT_DIR}/../assets
source ${THIS_SCRIPT_DIR}/pipeline.sh

PROCESS=$(basename $0 .sh)
ARGS=( START_DT \
  END_DT \
  SOURCE \
  DEST \
  TEMP_TABLE )

echo -e "\nRunning:\n${PROCESS}.sh $@ \n"

display_usage() {
  echo -e "\nUsage:\n${PROCESS}.sh ${ARGS[*]}\n"
  echo -e "START_DT: The start date expressed with the following format YYYY-MM-DD.\n"
  echo -e "END_DT: The end date expressed with the following format YYYY-MM-DD.\n"
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

START_YEAR=${START_DT:0:4}
END_YEAR=${END_DT:0:4}

YEAR=$(($START_YEAR))
while [[ "$YEAR" -le "$END_YEAR"  ]]; do 

  ################################################################################
  # Loads the DCA LOGBOOK into a temp table
  ################################################################################
  echo
  echo "Loads the $YEAR DCA LOGBOOK into a temp table"
  
  SCHEMA=${ASSETS}/temp_logbook_raw_schema.json
  # Get the most recent gzip file for the YEAR
  response=(`gsutil ls -l ${SOURCE}/${YEAR}* | grep -i "dca.csv.gz" | sort -k 2 | tail -n 2 | head -1`)
  GCS_SOURCE=${response[2]}

  if [ "$?" -ne 0 ]; then
    echo "  Could not find a logbook's report csv file for the given day on ${GCS_SOURCE}."
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
    echo "  Unable to load the DCA LOGBOOK."
    display_usage
    exit 1
  fi


  ################################################################################
  # Removes the partitions on DCA logbook table before inserting the new positions
  ################################################################################
  echo
  echo "Removing logbook data on ${DEST} from ${START_DT} to ${END_DT}"
  jinja2 ${ASSETS}/delete_logbook_raw_data.sql.j2 \
    -D dest=${DEST} \
    -D start_date=${START_DT} \
    -D end_date=${END_DT} \
    | bq query -q \
      --nouse_legacy_sql


  ################################################################################
  # Loads the DCA LOGBOOK DATA into the raw table
  ################################################################################
  echo
  echo "Loads the DCA LOGBOOK into the RAW table"
  SQL=${ASSETS}/load_logbook_raw_data.sql.j2
  SCHEMA=${ASSETS}/logbook_raw_schema.json

  jinja2 ${SQL} \
    -D source=${TEMP_TABLE} \
    -D start_date=${START_DT} \
    -D end_date=${END_DT} \
    | bq query -q --max_rows=0 --allow_large_results \
      --append_table \
      --nouse_legacy_sql \
      --destination_schema ${SCHEMA} \
      --destination_table ${DEST}

  if [ "$?" -ne 0 ]; then
    echo "  Unable to load the DCA LOGBOOK DATA into the raw table ${DEST}"
    display_usage
    exit 1
  fi

  #############################################################
  # Updates the table description.
  #############################################################
  echo 
  echo "Updating table description ${DEST}"
  TABLE_DESC=(
    "* Pipeline: ${PIPELINE} ${PIPELINE_VERSION}"
    "* Source: DCA LOGBOOK ${SOURCE}"
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

  #############################################################
  # Deletes the temp table description.
  #############################################################
  echo 
  echo "Deleting temp table ${TEMP_TABLE}"
  bq rm -f ${TEMP_TABLE}
  if [ "$?" -ne 0 ]; then
    echo "  Unable to delete temp table ${TEMP_TABLE}"
    display_usage
    exit 1
  fi


  echo "============================================"
  echo 
  YEAR=$(($YEAR + 1 ))
done
echo "${DEST} Done."
