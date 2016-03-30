if (( $# != 3 ))
then
  echo "Usage: ${0} SENSORS MEASURES RUNS"
  exit 1;
fi

SENSORS=${1}
MEASURES=${2}
RUNS=${3}

MY_USER=MSPublisher
MY_PASSWD=ferf345gootkndssdyrwt
MY_QOS=1
MY_HOST=wg66.waag.org

function publish {
MSR=${1}
for (( d=1; d<=${SENSORS}; d++ ))
do
  ID="${d}"

  RND_TXT=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
  #MY_MSG="{\"measure\":\"${RND_TXT}\",\"id\":${ID}}"
  MY_MSG="{\"measure\":\"${ID}_${MSR}\",\"id\":${ID}}"

	RESULT="$(mosquitto_pub -h ${MY_HOST} -u ${MY_USER} -P ${MY_PASSWD} -i ${ID} -t sensor/${ID}/data -m $MY_MSG -q ${MY_QOS} 2>&1 ) "
  #echo _${RESULT}_

	#if ! echo ${RESULT} | gSENSORS "${1}" >/dev/null
	if [ "${RESULT} " != "  " ]
	then
		echo "ERROR: ${RESULT}"
	else
    :
		#echo "DONE"
	fi
done
}

function test {

for (( c=1; c<=${MEASURES}; c++ ))
do
	#echo ${c};
	publish ${c} &
done

wait
}

function runTest {

for (( run=1; run<=${RUNS}; run++ ))
	do
		echo "Testing ${SENSORS} Sensors each with ${MEASURES} measures, run ${run} of ${RUNS}"
		time test
	done
}

clear

time runTest
