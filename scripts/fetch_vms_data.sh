#!/usr/bin/env bash
set -e

source pipe-tools-utils
THIS_SCRIPT_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )"
ASSETS=${THIS_SCRIPT_DIR}/../assets
source ${THIS_SCRIPT_DIR}/pipeline.sh

# Norway base url where zip files will be placed: 
#  Eg: https://register.fiskeridir.no/vms-ers/
BASE_URL="https://register.fiskeridir.no/vms-ers"
CURRENTDATE=`date +"%Y%m%d%H%M%S"`

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
  YEAR=$1
  OUTFILE="${TEMP}/${CURRENTDATE}.${YEAR}-VMS.csv.zip"
  wget "${BASE_URL}/${YEAR}-VMS.csv.zip" -O ${OUTFILE}
  if [ ! $? -eq 0 ]; then
    return 1
  fi
  echo ${OUTFILE}
}

convert_zip_to_gzip () {
  ZIPFILE=$1
  unzip ${ZIPFILE}/*.zip  -d ${TEMP}
  rm -f ${TEMP}/*.zip
  gzip ${TEMP}/*
  GZIPFILE=`ls -1 ${TEMP}`
  echo "${TEMP}/${GZIPFILE}"
}

################################################################################
# Moves the data to GCS.
################################################################################
move_to_gcs() {
  SOURCE=$1
  echo
  GCS_DESTINATION=${DEST}/${DT}/
  echo "Moves the data to GCS. ${GCS_DESTINATION}" 
  # Check that the folder exists in GCS before deleting it to prevent failures
  gsutil -q stat "${GCS_DESTINATION}*"
  if [ $? -eq 0 ]; then
    return 1

    # Do not clear yet the contents of the day's folder
    # if ! gsutil -m rm -f "${GCS_DESTINATION}*" ; then
    #   return 1
    # fi
  fi
  
  gsutil -m cp ${SOURCE} ${GCS_DESTINATION}
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

YEAR=${DT:0:4}
exit_code=0

echo 
echo "Downloads the NORWAY positions for year ${YEAR}."
zipfile=`fetch_vms_data $YEAR || exit_code=$?`

if [ $exit_code -eq 0 ]; then
    gzipfile=`convert_zip_to_gzip $zipfile || exit_code=$?`
  if [ $exit_code -eq 0 ]; then
      move_to_gcs $gzipfile || exit_code=$?
  fi
fi

clean_temp_folder || exit_code=$?

exit $exit_code
