if (( $# != 3 ))
then
  echo "Usage: ${0} <nr sensors> <nr measures> <host>"
  exit 1;
fi

if ! which mosquitto_pub >/dev/null
then
  echo "mosquitto_pub is not installed, exiting"
  exit 1;
fi

parse_yaml() {
  FILE=${1}
  CONTEXT=${2}
  FIELD=${3}

  #echo "FILE=${FILE}, CONTEXT=${CONTEXT}, FIELD=${FIELD}"

   awk  "
   BEGIN {i=0}
   /${CONTEXT}:/ {i=1;next}
   i && /${FIELD}:/ {print \$2;i=0}
   " ${FILE}

}

## find conf dir

CONF_FILE=$(find ../ -name makingsense.yaml)
#echo ${CONF_FILE}

## Test mosquitto agent
MY_USER=$(parse_yaml ${CONF_FILE} mqtt username)
MY_PASSWD=$(parse_yaml ${CONF_FILE} mqtt password)

#echo ${MY_USR} ${MY_PWD}


SENSORS=${1}
MEASURES=${2}

MY_HOST=${3}

MY_QOS=0


function publish {
MSR=${1}
for (( d=1; d<=${SENSORS}; d++ ))
do
  ID="${d}"
  #ID=$(echo $[ 1 + $[ RANDOM % 15 ]])

  #RND_TXT=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
  #MY_MSG="{\"measure\":\"${RND_TXT}\",\"id\":${ID}}"
  if (( $[ 1 + $[ RANDOM % 9 ]] > 6 ))
  then
    MY_MSG="{\"garbage\"\"}"
  else
#    MY_MSG="{\"id\":${ID},\"rssi\":-63,\"temp\":\"21.06\",\"pm10\":\"213.0\",\"pm2.5\":\"88.0\",\"no2a\":\"1054.0\",\"no2b\":\"1103.0\"}"
    MY_MSG="{\"i\":26296,\"r\":-76,\"t\":\"26.30\",\"a\":\"1197\",\"b\":\"1197\",\"p10\":\"128.68\",\"p2.5\":\"432.25\",\"h\":\"44.10\"}"

  fi

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
    sleep 5s
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
	echo "Testing ${SENSORS} Sensors each with ${MEASURES} measures with randomly incorrect messages"
	time test
}

clear

time runTest
