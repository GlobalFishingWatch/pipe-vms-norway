#!/usr/bin/env bash
set -e

source pipe-tools-utils
THIS_SCRIPT_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )"
ASSETS=${THIS_SCRIPT_DIR}/../assets
source ${THIS_SCRIPT_DIR}/pipeline.sh

# Norway base url where zip files will be placed: 
#  Eg: https://register.fiskeridir.no/vms-ers/
BASE_URL="https://register.fiskeridir.no/vms-ers"

PROCESS=$(basename $0 .sh)
ARGS=( DEST \
  DT )

echo -e "\nRunning:\n${PROCESS}.sh $@ \n"

display_usage() {
  echo -e "\nUsage:\n${PROCESS}.sh ${ARGS[*]}\n"
  echo -e "DEST: GCS destination path where the file will uploaded.\n"
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


################################################################################
# Creates a temporary folder.
################################################################################
create_temp_folder () {
  echo
  echo "Creates a temporary folder"
  TEMP=$(mktemp -d)
  echo "Temporary Directory: ${TEMP}"
}

################################################################################
# Downloads the NORWAY current year positions.
################################################################################
fetch_vms_data () {
  YEAR=${DT:0:4}
  YEAR_BEFORE=`expr $YEAR - 1`
  echo 
  echo "Downloads the NORWAY positions for year ${YEAR}."
  wget "${BASE_URL}/${YEAR}-VMS.csv.zip" -P ${TEMP}
  if [ ! $? -eq 0 ]; then
    echo "Positions for year ${YEAR} not found yet"
    echo "Downloads the NORWAY positions for the year before: ${YEAR_BEFORE}."
    wget "${BASE_URL}/${YEAR_BEFORE}-VMS.csv.zip" -P ${TEMP}
    if [ ! $? -eq 0 ] ; then
      echo "Positions for year ${YEAR} neither found."
      return 1
    fi
  fi
}

################################################################################
# Moves the data to GCS.
################################################################################
move_to_gcs() {
  echo
  echo "Moves the data to GCS."
  GCS_DESTINATION=${DEST}/${DT}/
  # Check that the folder exists in GCS before deleting it to prevent failures
  gsutil -q stat "${GCS_DESTINATION}*"
  if [ $? -eq 0 ]; then
    if ! gsutil -m rm -f "${GCS_DESTINATION}*" ; then
      return 1
    fi
  fi
  
  gsutil -m cp ${TEMP}/* ${GCS_DESTINATION}
}

################################################################################
# Cleans the temp folder.
################################################################################
clean_temp_folder() {
  echo
  echo "Cleans the temp folder."
  rm -rf ${TEMP}
}

################################################################################
# Main execution flow
################################################################################
create_temp_folder || exit $?

exit_code=0
fetch_vms_data || exit_code=$?
if [ $exit_code -eq 0 ]; then
    move_to_gcs || exit_code=$?
fi

clean_temp_folder || exit_code=$?

exit $exit_code
