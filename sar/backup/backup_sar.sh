#!/usr/bin/env ksh

#Functions
##echo error message to stderr
error_message(){
	echo ${1} >&2
}

##check if parameter is a readable file
check_readable(){
	if [ \( -f ${1} \) -a \( -r ${1} \) ]; then
		return
	fi
	error_message "File '${1}' not found or not readable"
	exit 1
}

##check if parameter is an executable file
check_executable(){
	if [ \( -f ${1} \) -a \( -x ${1} \) ]; then
	          return
	fi
	error_message "File '${1}' not found or not executable"
	exit 1
}

#Read config values
SCRIPT_DIR=`dirname ${0}`
SCRIPT_NAME=`basename ${0} .sh`
CONFIG_FILE=${SCRIPT_DIR}/${SCRIPT_NAME}.config
check_readable ${CONFIG_FILE}
source ${CONFIG_FILE}

#Check executables
check_executable ${SAR}
check_executable ${TAR}
check_executable ${FIND}
check_executable ${RM}
check_executable ${DATE}
check_executable ${UNAME}

#Get input and output file suffixes
OUTPUT_DATE=`${DATE} ${OUTPUT_DATE_FORMAT}`
INPUT_DATE=`${DATE} ${INPUT_DATE_FORMAT}`
#get system name
SYSTEM_NAME=`${UNAME} -n`
#binary input file
DFILE=${INPUT_DIR}/sa${INPUT_DATE}
	
#Input file must be readable
check_readable ${DFILE}

#Check output directory (must be directory, searchable and writable)
if [ \! \( \( \( -d ${OUTPUT_DIR} \) -a \( -x ${OUTPUT_DIR} \) \) -a \( -w ${OUTPUT_DIR} \) \) ]; then
	echo "Output directory '${OUTPUT_DIR}' not exists, or not a writable and searchable directory" >&2
	exit 2
fi

#Copy input to output directory
cp ${DFILE} ${OUTPUT_DIR}/sa_${SYSTEM_NAME}${OUTPUT_DATE}
#For all swithes create text report with a name ending with the switch
for switch in ${SAR_SWITCHES[@]}
do
	flags=-${switch}
	if [ -n SAR_START_TIME ]; then
		flags="${flags} -s ${SAR_START_TIME}"
	fi
	if [ -n SAR_END_TIME ]; then
		flags="${flags} -e ${SAR_END_TIME}"
	fi
	${SAR} ${flags} -f ${DFILE} > ${OUTPUT_DIR}/sar_${SYSTEM_NAME}${OUTPUT_DATE}.${switch}
done
cd ${OUTPUT_DIR}
#Tar and compress created files
${TAR} -cvzf ${OUTPUT_PREFIX}${SYSTEM_NAME}${OUTPUT_DATE}.tgz sa_${SYSTEM_NAME}${OUTPUT_DATE} sar_${SYSTEM_NAME}${OUTPUT_DATE}.*
#Remove files that were tarred in the previous step
${RM} sa_${SYSTEM_NAME}${OUTPUT_DATE} sar_${SYSTEM_NAME}${OUTPUT_DATE}.*
#Remove files that are older than KEEP_DATA_DAYS
${FIND} . -name "${OUTPUT_PREFIX}${SYSTEM_NAME}*" -mtime +${KEEP_DATA_DAYS} -exec ${RM} {} \;

