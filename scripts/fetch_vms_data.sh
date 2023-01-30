#!/usr/bin/env bash
set -e

source pipe-tools-utils
THIS_SCRIPT_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )"
ASSETS=${THIS_SCRIPT_DIR}/../assets
source ${THIS_SCRIPT_DIR}/pipeline.sh

# Norway base url where zip files will be placed: 
#  Eg: https://register.fiskeridir.no/vms-ers/
REPORTSINDEXURL="https://www.fiskeridir.no/Tall-og-analyse/AApne-data/posisjonsrapportering-vms"
CURRENTDATE=`date +"%Y%m%d%H%M%S"`

PROCESS=$(basename $0 .sh)
ARGS=( DEST \
  START_DT \
  END_DT)

echo -e "\nRunning:\n${PROCESS}.sh $@ \n"

display_usage() {
  echo -e "\nUsage:\n${PROCESS}.sh ${ARGS[*]}\n"
  echo -e "DEST: GCS destination path where the file will uploaded.\n"
  echo -e "START_DT: The start date expressed with the following format YYYY-MM-DD.\n"
  echo -e "END_DT: The end date expressed with the following format YYYY-MM-DD.\n"
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
# Gets the zip file url for the given YEAR
################################################################################
get_file_url () {
  YEAR=$1
  # Fetch the list of archives available to download
  ZIPURL=`wget -q -O- ${REPORTSINDEXURL} | \
    # Find all the links
    grep -ioE "<a href=\"([^\"]+)\"[^>]*>[^<]+($YEAR)[^<]+" | \
    # filter only those that contains .zip 
    grep -E '.*\.zip"' | \
    # extract omly the url
    sed -r 's#<a href="([^"]+)"[^>]*+*>[^<]+([0-9]{4})[^<]+$#\1#' | \
    # add the domain if the link does not have it
    sed -r 's#(^\/.*)#https://www.fiskeridir.no\1#'`
  
  if [ -z "$ZIPURL" ]; then
    # When the file to download is not found in ther downloads page
    # we'll use the predefined list of files for years 2011-2021 and
    # a general rule for the files from 2022 and on

    if [[ $(($YEAR)) -ge 2022 ]]; then
      # Starting in 2022 the files will (hopefully) be published in 
      # https://register.fiskeridir.no/vms-ers/${YEAR}-VMS.csv.zip
      ZIPURL="https://register.fiskeridir.no/vms-ers/${YEAR}-VMS.csv.zip"
    else
      # Between 2011 and 2021 we should use this predefined list
      ZIPLIST="2021|https://www.fiskeridir.no/Tall-og-analyse/AApne-data/posisjonsrapportering-vms/_/attachment/download/d8736f20-309c-4b29-9786-a8d8271418c4:300bd8f940c7856c2fbeb4b2053d4fcd989f43e2/posisjonsrapportering-vms-2021-pos.zip
2020|https://www.fiskeridir.no/Tall-og-analyse/AApne-data/posisjonsrapportering-vms/_/attachment/download/6cba325a-4f84-4002-905a-7f25d4a6cfca:75ca7ee9be41703018c77cfc6ffa61d2d9c89b54/posisjonsrapportering-vms-2020-pos.zip
2019|https://www.fiskeridir.no/Tall-og-analyse/AApne-data/posisjonsrapportering-vms/_/attachment/download/46c58ae4-ef97-4341-8091-c0e6e2a91398:349529ab7b91aec15b07f395222854257186bdf8/posisjonsrapportering-vms-2019-pos.zip
2018|https://www.fiskeridir.no/Tall-og-analyse/AApne-data/posisjonsrapportering-vms/_/attachment/download/58039e8f-8b3b-469c-bafa-242f8076fefb:4fd644cf9e8c2aba415a0dc7d6e278d0e6152c39/posisjonsrapportering-vms-2018-pos.zip
2017|https://www.fiskeridir.no/Tall-og-analyse/AApne-data/posisjonsrapportering-vms/_/attachment/download/150d09d9-1d6c-4168-953d-9266b2aaa120:97ad1c34216cc01af9804fc7221f079b427f0bbc/posisjonsrapportering-vms-2017-pos.zip
2016|https://www.fiskeridir.no/Tall-og-analyse/AApne-data/posisjonsrapportering-vms/_/attachment/download/fe17a8a2-eed3-43a4-868d-c84699d50953:16922efa37906d3096c174481c884d90d5e3abe1/posisjonsrapportering-vms-2016-pos.zip
2015|https://www.fiskeridir.no/Tall-og-analyse/AApne-data/posisjonsrapportering-vms/_/attachment/download/a89b811e-76cf-4660-8d27-ee7bf44ecd1c:42441a3d6e044f750019e8c033d2041445211454/posisjonsrapportering-vms-2015-pos.zip
2014|https://www.fiskeridir.no/Tall-og-analyse/AApne-data/posisjonsrapportering-vms/_/attachment/download/45ce7608-5b72-4b61-9894-73a5d7ebe77c:b0fd74ccc40eefad69ba3c30a59e296ac00bca42/posisjonsrapportering-vms-2014-pos.zip
2013|https://www.fiskeridir.no/Tall-og-analyse/AApne-data/posisjonsrapportering-vms/_/attachment/download/d963aac6-8b02-4c21-a694-ce506bd735c0:cf0e61502e0f38728e7fb81508551f9cf0023036/posisjonsrapportering-vms-2013-pos.zip
2012|https://www.fiskeridir.no/Tall-og-analyse/AApne-data/posisjonsrapportering-vms/_/attachment/download/f51512f5-5387-4311-955a-4d27503989bf:bcb1aa871de370dbbd7be50851f31d308d1e4015/posisjonsrapportering-vms-2012-pos.zip
2011|https://www.fiskeridir.no/Tall-og-analyse/AApne-data/posisjonsrapportering-vms/_/attachment/download/a6d73f29-21ad-44a1-b328-aec19fd62744:9d2f30adddd2bf8f2eb14e15e480df8df3c2415a/posisjonsrapportering-vms-2011-pos.zip"
      ZIPURL=`echo "$ZIPLIST" | | grep -Po "(?<=${YEAR}\|).*"`
    fi
  fi

  if [ -z "$ZIPURL" ]; then
    echo "Could not find the positions report csv file to download for year ${YEAR} on ${REPORTSINDEXURL}."
    return 1
  fi
  echo $ZIPURL
}
################################################################################
# Downloads the NORWAY current year positions.
################################################################################
fetch_vms_data () {
  ZIPURL=$1
  YEAR=$2
  OUTFILE="${TEMP}/${CURRENTDATE}.${YEAR}-VMS.csv.zip"
  wget -q "${ZIPURL}" -O ${OUTFILE}
  if [ ! $? -eq 0 ]; then
    echo "Error downloading yearly csv report ${ZIPURL}."
    return 1
  fi
  echo ${OUTFILE}
}

convert_zip_to_gzip () {
  ZIPFILE=$1
  unzip ${ZIPFILE} -d ${TEMP}
  CSVFILE=`ls -1t ${TEMP}/*.csv | head -n 1`
  if [ -z "$CSVFILE" ]; then
    echo "Could not find a csv file inside the Zip file ${ZIPFILE}."
    return 1
  fi
  NEWCSVFILE=`ls -1t ${TEMP}/*.csv | head -n 1 | sed -r "s#${TEMP}/(.*)#${TEMP}/${CURRENTDATE}.\1#"`
  if [ -z "$NEWCSVFILE" ]; then
    echo "Could not generate the new filename for the csv ${CSVFILE} with the timestamp prefix."
    return 1
  fi
  mv ${CSVFILE} ${NEWCSVFILE}
  rm -f ${ZIPFILE}
  gzip -9 ${TEMP}/*
}

################################################################################
# Moves the data to GCS.
################################################################################
move_to_gcs() {
  GCS_DESTINATION=${DEST}/$1/
  echo
  echo "Moves the data to GCS. ${GCS_DESTINATION}" 
  
  # SKIP THIS. Do not clear yet the contents of the day's folder
  # # Check that the folder exists in GCS before deleting it to prevent failures
  # gsutil -q stat "${GCS_DESTINATION}*"
  # if [ $? -eq 0 ]; then
  #   return 1

  #   # if ! gsutil -m rm -f "${GCS_DESTINATION}*" ; then
  #   #   return 1
  #   # fi
  # fi
  
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
START_YEAR=${START_DT:0:4}
END_YEAR=${END_DT:0:4}

exit_code=0
YEAR=$(($START_YEAR))
while [[ "$YEAR" -le "$END_YEAR" && $exit_code -eq 0 ]]; do 
  echo "Fetching data for year: $YEAR"
  create_temp_folder || exit $?

  echo 
  echo "Gets the NORWAY positions for year ${YEAR}."
  fileurl=`get_file_url $YEAR || exit_code=$?`

  # To Improve: ONLY FETCH IF THE FILE on their server CHANGED compare to ours
  # or if we dont have it
  if [ $exit_code -eq 0 ]; then
    echo 
    echo "Downloads the NORWAY positions for year ${YEAR}."
    echo "$fileurl"
    zipfile=`fetch_vms_data ${fileurl} ${YEAR} || exit_code=$?`
  fi
  if [ $exit_code -eq 0 ]; then
    echo 
    echo "Converts ${zipfile} to gzip for bq load."
    convert_zip_to_gzip $zipfile || exit_code=$?
  fi
  if [ $exit_code -eq 0 ]; then
      GCS_DAY_FOLDER=$YEAR
      if [[ "$YEAR" -eq "$END_YEAR" ]]; then
          GCS_DAY_FOLDER=$END_DT
      fi
      move_to_gcs $GCS_DAY_FOLDER || exit_code=$?
  fi

  # Always clean temp folder
  clean_temp_folder || exit_code=$?

  YEAR=$(($YEAR + 1 ))
done
exit $exit_code
