#!/bin/bash
INPUT_FILE=/remotelogs/syslog_location_prefixes.txt
OUTPUT_FILE=/remotelogs/syslog_recon_rpt.csv

echo "MIME-Version: 1.0" > $OUTPUT_FILE
echo "Content-Type: text/html; charset=utf8" >> $OUTPUT_FILE
echo "from: XNLogUser<alerts@xceednet.com>" >> $OUTPUT_FILE
echo "Subject: Syslog Reconciliation - Daily Report" >> $OUTPUT_FILE
echo "<html>" >> $OUTPUT_FILE
echo "<head>" >> $OUTPUT_FILE
echo "<style>" >> $OUTPUT_FILE
echo "table, th, td {" >> $OUTPUT_FILE
echo "  border: 1px solid black;" >> $OUTPUT_FILE
echo "  border-collapse: collapse;" >> $OUTPUT_FILE
echo "}" >> $OUTPUT_FILE
echo "td {" >> $OUTPUT_FILE
echo "  padding: 5px;" >> $OUTPUT_FILE
echo "}" >> $OUTPUT_FILE
echo "th {" >> $OUTPUT_FILE
echo "  padding: 5px;" >> $OUTPUT_FILE
echo "  text-align: center;" >> $OUTPUT_FILE
echo "  font-weight: bold;" >> $OUTPUT_FILE
echo "  background-color: lightblue;" >> $OUTPUT_FILE
echo "}" >> $OUTPUT_FILE
echo "tr:nth-child(even) {background-color: #f2f200;}" >> $OUTPUT_FILE
echo "</style>" >> $OUTPUT_FILE
echo "</head>" >> $OUTPUT_FILE

echo "<body>" >> $OUTPUT_FILE
echo "<h2>Syslog Reconciliation - Daily Report</h2>" >> $OUTPUT_FILE
echo "<h3>1. Either Location/Operator/ISP is disabled OR the setting for logs_maintained_by_xceednet is FALSE but syslogs are still getting generated</h3>" >> $OUTPUT_FILE

echo "<table><tr><th>URL</th><th>Syslog Prefix</th><th>NAS IP</th><th>Error Description</th></tr>" >> $OUTPUT_FILE

ACTIVE_PREFIX_AND_IP_ARRAY=( $( find /remotelogs -type f -mtime -2 -name syslog | sed '/^.*\/remotelogs\/message .*$/d' | sed 's/^\/remotelogs\///g' | cut -d '/' -f1,2 | sort -u ) )
PARENT_LOCATION_PREFIX_ARRAY=()
SUBLOCATION_PREFIX_ARRAY=()
for PREFIX_AND_IP in "${ACTIVE_PREFIX_AND_IP_ARRAY[@]}"
do
	IFS='\/' read -ra PREFIX_AND_IP_ARRAY <<< ${PREFIX_AND_IP}
	LOCATION_PREFIX=${PREFIX_AND_IP_ARRAY[0]}
	NAS_IP=${PREFIX_AND_IP_ARRAY[1]}

	#echo "LOCATION_PREFIX: ${LOCATION_PREFIX}"
	#echo "NAS_IP: ${NAS_IP}"

	IFS='|' read -ra LOCATION_PREFIX_DATA <<< $( grep ${LOCATION_PREFIX} ${INPUT_FILE} )
	LOCATION_ID=${LOCATION_PREFIX_DATA[0]}
	LOCATION_URL=${LOCATION_PREFIX_DATA[1]}
	IS_SUBLOCATION=${LOCATION_PREFIX_DATA[3]}
	LOGS_MAINTAINED_BY_XCEEDNET=${LOCATION_PREFIX_DATA[4]}
	IS_LOCATION_DISABLED=${LOCATION_PREFIX_DATA[5]}
	IS_OPERATOR_DISABLED=${LOCATION_PREFIX_DATA[6]}
	IS_ISP_DISABLED=${LOCATION_PREFIX_DATA[7]}
	ONLINE_SUBSCRIBER_COUNT=${LOCATION_PREFIX_DATA[8]}

	#echo "LOCATION_ID_1: ${LOCATION_ID}"
	#echo "LOCATION_URL_1: ${LOCATION_URL}"
	#echo "IS_SUBLOCATION_1: ${IS_SUBLOCATION}"
	#echo "LOGS_MAINTAINED_BY_XCEEDNET_1: ${LOGS_MAINTAINED_BY_XCEEDNET}"
	#echo "IS_LOCATION_DISABLED_1: ${IS_LOCATION_DISABLED}"
	#echo "IS_OPERATOR_DISABLED_1: ${IS_OPERATOR_DISABLED}"
	#echo "IS_ISP_DISABLED_1: ${IS_ISP_DISABLED}"
	#echo "ONLINE_SUBSCRIBER_COUNT_1: ${ONLINE_SUBSCRIBER_COUNT}"

	if [ "${IS_SUBLOCATION}" == "1" ]; then
		SUBLOCATION_PREFIX_ARRAY+=("${LOCATION_PREFIX}")
		continue
	else
		PARENT_LOCATION_PREFIX_ARRAY+=("${LOCATION_PREFIX}")
	fi

	OUTPUT_STR="<tr><td>${LOCATION_URL}</td><td>${LOCATION_PREFIX}</td><td>${NAS_IP}</td>"

	if [ "${IS_LOCATION_DISABLED}" == "1" ]; then
		OUTPUT_STR+="<td>Location Status is Disabled</td>"
	elif [ "${IS_OPERATOR_DISABLED}" == "1" ]; then
		OUTPUT_STR+="<td>Operator Status is Disabled</td>"
	elif [ "${IS_ISP_DISABLED}" == "1" ]; then
		OUTPUT_STR+="<td>ISP Status is Disabled</td>"
	elif [ "${LOGS_MAINTAINED_BY_XCEEDNET}" == "0" ]; then
		OUTPUT_STR+="<td>Syslogs are not maintained by Xceednet</td>"
	else
		continue
	fi

	OUTPUT_STR+="</tr>"
	echo ${OUTPUT_STR} >> $OUTPUT_FILE
done

echo "</table></body></html>" >> $OUTPUT_FILE

echo "<br><br>" >> $OUTPUT_FILE
echo "<h3>2. Location is Active AND the setting for logs_maintained_by_xceednet is TRUE but syslogs are NOT getting generated</h3>" >> $OUTPUT_FILE

echo "<table>" >> $OUTPUT_FILE
echo "<tr><th>URL</th><th>Syslog Prefix</th></tr>" >> $OUTPUT_FILE

while IFS= read -r INPUT_FILE_ROW
do
	IFS='|' read -ra LOCATION_PREFIX_DATA <<< ${INPUT_FILE_ROW}
	LOCATION_ID=${LOCATION_PREFIX_DATA[0]}
	LOCATION_URL=${LOCATION_PREFIX_DATA[1]}
	LOCATION_PREFIX=${LOCATION_PREFIX_DATA[2]}
	IS_SUBLOCATION=${LOCATION_PREFIX_DATA[3]}
	LOGS_MAINTAINED_BY_XCEEDNET=${LOCATION_PREFIX_DATA[4]}
	IS_LOCATION_DISABLED=${LOCATION_PREFIX_DATA[5]}
	IS_OPERATOR_DISABLED=${LOCATION_PREFIX_DATA[6]}
	IS_ISP_DISABLED=${LOCATION_PREFIX_DATA[7]}
	ONLINE_SUBSCRIBER_COUNT=${LOCATION_PREFIX_DATA[8]}

	#echo "LOCATION_ID_2: ${LOCATION_ID}"
	#echo "LOCATION_URL_2: ${LOCATION_URL}"
	#echo "LOCATION_PREFIX_2: ${LOCATION_PREFIX}"
	#echo "IS_SUBLOCATION_2: ${IS_SUBLOCATION}"
	#echo "LOGS_MAINTAINED_BY_XCEEDNET_2: ${LOGS_MAINTAINED_BY_XCEEDNET}"
	#echo "IS_LOCATION_DISABLED_2: ${IS_LOCATION_DISABLED}"
	#echo "IS_OPERATOR_DISABLED_2: ${IS_OPERATOR_DISABLED}"
	#echo "IS_ISP_DISABLED_2: ${IS_ISP_DISABLED}"
  #echo "ONLINE_SUBSCRIBER_COUNT_2: ${ONLINE_SUBSCRIBER_COUNT}"

	if [ "${IS_SUBLOCATION}" == "1" ]; then
		continue
	fi

	if [[ "${IS_LOCATION_DISABLED}" == "0" && \
		"${IS_OPERATOR_DISABLED}" == "0" && \
		"${IS_ISP_DISABLED}" == "0" && \
		"${LOGS_MAINTAINED_BY_XCEEDNET}" == "1" && \
		"${ONLINE_SUBSCRIBER_COUNT}" != "0" && \
		! " ${PARENT_LOCATION_PREFIX_ARRAY[*]} " =~ " ${LOCATION_PREFIX} " ]]; then
		#echo " ${LOCATION_PREFIX_ARRAY[*]} "
		echo "<tr><td>${LOCATION_URL}</td><td>${LOCATION_PREFIX}</td></tr>" >> $OUTPUT_FILE
	fi

done < "${INPUT_FILE}"

echo "</table><br><br>" >> $OUTPUT_FILE

echo "<h3>3. Log files with large size.</h3>" >> $OUTPUT_FILE
echo "<table>" >> $OUTPUT_FILE
echo "<tr><th>File Size</th><th>Online Subscribers<br>Count</th><th>URL</th><th>Syslog File</th></tr>" >> $OUTPUT_FILE

LARGE_SYSLOG_FILES_ARRAY=( $( find /remotelogs -type f -size +256M -name "syslog" -exec ls -al {} \; | sed '/^.*\/remotelogs\/message .*$/d' | awk -F ' ' '{ TP1 = $9; split(TP1, PREFIX_AND_IP, "/"); print $5, $9, PREFIX_AND_IP[3] }' | sort -n -r | numfmt --field=1 --to=iec --format "%8f" | sed 's/^[ ][ ]*//g' | sed 's/ /|/g' ) )
for LARGE_SYSLOG_FILE in "${LARGE_SYSLOG_FILES_ARRAY[@]}"
do
	#echo ${LARGE_SYSLOG_FILE}
	IFS='\|' read -ra SYSLOG_FILENAME_AND_SIZE <<< ${LARGE_SYSLOG_FILE}

	IFS='|' read -ra LOCATION_PREFIX_DATA <<< $( grep ${SYSLOG_FILENAME_AND_SIZE[2]} ${INPUT_FILE} )
	LOCATION_URL=${LOCATION_PREFIX_DATA[1]}
	ONLINE_SUBSCRIBER_COUNT=${LOCATION_PREFIX_DATA[8]}

	echo "<tr><td style='text-align: center'>${SYSLOG_FILENAME_AND_SIZE[0]}</td><td style='text-align: center'>${ONLINE_SUBSCRIBER_COUNT}</td><td>${LOCATION_URL}</td><td>${SYSLOG_FILENAME_AND_SIZE[1]}</td></tr>" >> $OUTPUT_FILE
done

echo "</table><br><br>" >> $OUTPUT_FILE

cat $OUTPUT_FILE | /usr/sbin/ssmtp support@xceednet.com
