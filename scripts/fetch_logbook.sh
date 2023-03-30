#!/usr/bin/env bash
set -e

source pipe-tools-utils
THIS_SCRIPT_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )"
ASSETS=${THIS_SCRIPT_DIR}/../assets
source ${THIS_SCRIPT_DIR}/pipeline.sh

# Norway base url where zip files will be placed: 
#  Eg: https://register.fiskeridir.no/vms-ers/
REPORTSINDEXURL="https://www.fiskeridir.no/Tall-og-analyse/AApne-data/elektronisk-rapportering-ers"
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
      # https://register.fiskeridir.no/vms-ers/${YEAR}-ERS-DCA.csv.zip
      ZIPURL="https://register.fiskeridir.no/vms-ers/${YEAR}-ERS-DEP.csv.zip https://register.fiskeridir.no/vms-ers/${YEAR}-ERS-POR.csv.zip https://register.fiskeridir.no/vms-ers/${YEAR}-ERS-TRA.csv.zip https://register.fiskeridir.no/vms-ers/${YEAR}-ERS-DCA.csv.zip"
    else
      # Between 2011 and 2022 we should use this predefined list
      ZIPLIST="2022|https://www.fiskeridir.no/Tall-og-analyse/AApne-data/elektronisk-rapportering-ers/_/attachment/download/2a9042cf-cb61-45d0-81e2-7786dd54381f:ce5fbcf4bf8da3ec55e0705b30fde5425d2764f0/elektronisk-rapportering-ers-2022.zip
2021|https://www.fiskeridir.no/Tall-og-analyse/AApne-data/elektronisk-rapportering-ers/_/attachment/download/337a59a1-6558-4c2a-9eae-2dead4aa09b5:09eb7a6c6427acba63ec23d1e195ea652051e870/elektronisk-rapportering-ers-2021.zip
2020|https://www.fiskeridir.no/Tall-og-analyse/AApne-data/elektronisk-rapportering-ers/_/attachment/download/9c646247-da57-4cfa-9be7-9f1686435c44:cba6190f435eeb88c2e0c225a98197840551445d/elektronisk-rapportering-ers-2020.zip
2019|https://www.fiskeridir.no/Tall-og-analyse/AApne-data/elektronisk-rapportering-ers/_/attachment/download/e1e59b82-ecf8-4122-aa16-878ecfbfc2e9:1cea6f381d9981436ed1bc3ad5d819a0974ee7a2/elektronisk-rapportering-ers-2019.zip
2018|https://www.fiskeridir.no/Tall-og-analyse/AApne-data/elektronisk-rapportering-ers/_/attachment/download/784c05bd-9ef6-425c-abfe-b9c3ee3b90b7:17df0f8ca7c82c11d3d673b306a94f79a200a57f/elektronisk-rapportering-ers-2018.zip
2017|https://www.fiskeridir.no/Tall-og-analyse/AApne-data/elektronisk-rapportering-ers/_/attachment/download/1e7a6b7f-78ae-4ccf-80cc-3d3ce649140b:dfb442acf363a1b8a9bf3e525c41b15bcd85c961/elektronisk-rapportering-ers-2017.zip
2016|https://www.fiskeridir.no/Tall-og-analyse/AApne-data/elektronisk-rapportering-ers/_/attachment/download/41e575d9-617e-494d-a4bb-0f8612eaa061:d9a93b57a3cfdcc725f53fcc4e5d151c0d2e34c9/elektronisk-rapportering-ers-2016.zip
2015|https://www.fiskeridir.no/Tall-og-analyse/AApne-data/elektronisk-rapportering-ers/_/attachment/download/a59cf002-f558-4095-86cf-730f38077616:ffd8d835160ee11080662ded9992b4094fa0abb3/elektronisk-rapportering-ers-2015.zip
2014|https://www.fiskeridir.no/Tall-og-analyse/AApne-data/elektronisk-rapportering-ers/_/attachment/download/c64857e6-4384-44db-a90e-6190ca7066b3:ceea78138640e4adffd0f0ff5be498ff29a24e42/elektronisk-rapportering-ers-2014.zip
2013|https://www.fiskeridir.no/Tall-og-analyse/AApne-data/elektronisk-rapportering-ers/_/attachment/download/dabe7e59-603c-4553-83ca-f81332ab36c2:ad3229a7f9887cc343990e0ca4834c33d529e386/elektronisk-rapportering-ers-2013.zip
2012|https://www.fiskeridir.no/Tall-og-analyse/AApne-data/elektronisk-rapportering-ers/_/attachment/download/fab9f6b7-65d8-401c-805f-28d4f21b31ed:6df3611602349b1b9930b03924ef0ddd41bba8c9/elektronisk-rapportering-ers-2012.zip
2011|https://www.fiskeridir.no/Tall-og-analyse/AApne-data/elektronisk-rapportering-ers/_/attachment/download/04f14bc2-daf3-4e42-8c16-970afbe88290:3e9891ffb23a1092630e76a5dfcbff7dee891008/elektronisk-rapportering-ers-2011.zip"
      ZIPURL=`echo "$ZIPLIST" | | grep -Po "(?<=${YEAR}\|).*"`
    fi
  fi
  if [ -z "$ZIPURL" ]; then
    echo "Could not find the ERS report csv file to download for year ${YEAR} on ${REPORTSINDEXURL}."
    return 1
  fi
  echo $ZIPURL
}
################################################################################
# Downloads the NORWAY current year logbook.
################################################################################
fetch_logbook () {
  URLS=`echo $1 | tr ' ' '\n'`
  YEAR=$2
  for ZIPURL in $URLS
  do 
    wget -q "${ZIPURL}" -P "${TEMP}"
    if [ ! $? -eq 0 ]; then
      echo "Error downloading yearly csv report ${ZIPURL}."
      return 1
    fi
  done
  ls -1t ${TEMP}/*.zip
}

convert_zip_to_gzip () {
  FILES=`echo $1 | tr ' ' '\n'`
  YEAR=$2
  for ZIPFILE in $FILES
  do 
    unzip ${ZIPFILE} -d ${TEMP}
    if [ ! $? -eq 0 ]; then
      echo "Error extracting Zip file ${ZIPFILE}."
      return 1
    fi
  done
  rm -f ${TEMP}/*.zip
  ls -1t ${TEMP}/*.csv | sed -r "s#${TEMP}/(.*)#${TEMP}/\1 ${TEMP}/${CURRENTDATE}.\1#" | xargs -L 1 mv -v
  gzip -9 ${TEMP}/*
}

################################################################################
# Moves the logbooks to GCS.
################################################################################
move_to_gcs() {
  GCS_DESTINATION=${DEST}/$1/
  echo
  echo "Moves the logbooks to GCS. ${GCS_DESTINATION}" 
  
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
  echo "Fetching logbook for year: $YEAR"
  create_temp_folder || exit $?

  set +e; 
  echo ;
  echo "Gets the NORWAY logbook for year ${YEAR}."
  fileurl=`get_file_url "$YEAR"`; 
  exit_code=$(($exit_code + $? )); 
  set -e

  # To Improve: ONLY FETCH IF THE FILE on their server CHANGED compare to ours
  # or if we dont have it
  if [ $exit_code -eq 0 ]; then
    set +e;
    echo "$fileurl" | tr ' ' '\n';
    echo ;
    echo "Downloads the NORWAY logbook for year ${YEAR}.";
    zipfile=`fetch_logbook "$fileurl" "${YEAR}"`;
    exit_code=$(($exit_code + $? ));
    set -e
  fi
  if [ $exit_code -eq 0 ]; then
    set +e;
    echo "$zipfile" ;
    echo ;
    echo "Converts ${zipfile} to gzip for bq load.";
    convert_zip_to_gzip "$zipfile" "${YEAR}";
    exit_code=$(($exit_code + $? ));
    set -e
  fi
  if [ $exit_code -eq 0 ]; then
    [[  "$YEAR" == "$END_YEAR" ]] && 
        GCS_DAY_FOLDER=$END_DT ||
        GCS_DAY_FOLDER=$YEAR
    set +e;
    move_to_gcs $GCS_DAY_FOLDER;
    exit_code=$(($exit_code + $? ));
    set -e
  fi

  # Always clean temp folder
  set +e;
  clean_temp_folder;
  exit_code=$(($exit_code + $? ));
  set -e
  echo "============================================"
  echo 
  YEAR=$(($YEAR + 1 ))
done
exit $exit_code
