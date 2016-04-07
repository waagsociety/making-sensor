if (( $# != 5 ))
then
  echo "Usage: ${0} <nr sensors> <nr measures> <nr runs> <user> <password>"
  exit 1;
fi

SENSORS=${1}
MEASURES=${2}
RUNS=${3}

MY_USER=${4}
MY_PASSWD=${5}
MY_QOS=1
MY_HOST=wg66.waag.org

function publish {
MSR=${1}
for (( d=1; d<=${SENSORS}; d++ ))
do
  ID="${d}"
  ID=$(echo $[ 1 + $[ RANDOM % 15 ]])

  #RND_TXT=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
  #MY_MSG="{\"measure\":\"${RND_TXT}\",\"id\":${ID}}"
  MY_MSG="{\"id\":${ID},\"rssi\":-63,\"temp\":\"21.06\",\"pm10\":\"213.0\",\"pm2.5\":\"88.0\",\"no2a\":\"1054.0\",\"no2b\":\"1103.0\"}"

  #echo "Sensor nr. ${d}"

  while true
  do
	#echo "mosquitto_pub -h ${MY_HOST} -u \"${MY_USER}\" -P \"${MY_PASSWD}\" -i \"${ID}\" -t \"sensor/${ID}/data\" -m \"$MY_MSG\" -q ${MY_QOS} 2>&1"
	RESULT="$(mosquitto_pub -h ${MY_HOST} -u "${MY_USER}" -P "${MY_PASSWD}" -i "${ID}" -t "sensor/${ID}/data" -m "$MY_MSG" -q ${MY_QOS} 2>&1 ) "
	#echo _${RESULT}_

	#if ! echo ${RESULT} | gSENSORS "${1}" >/dev/null
	if [ "${RESULT} " != "  " ]
	then
		echo "ERROR: ${RESULT}, retrying"
	else
		break
		#echo "DONE"
	fi
  done
  RND_SLEEP="0.$[ 1 + $[ RANDOM % 9 ]]"
  sleep ${RND_SLEEP}
done
}

function test {

for (( c=1; c<=${MEASURES}; c++ ))
do
	#echo ${c};
	echo "Measure nr. ${c}"
	publish ${c} &
	sleep 1
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
