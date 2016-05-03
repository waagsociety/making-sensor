# Backup DBs

BACKUPDIR=/Users/admin/SURFdrive/SocialGlassDataSets

DBs=( "airq" "traffic" )
SUFFIX="$(/bin/date +%H_%w).gz"

for (( i=0; i<${#DBs[@]}; i++ ))
do
        ( pg_dump -h localhost -p 9530 -U postgres ${DBs[${i}]} | /usr/bin/gzip --best > ${BACKUPDIR}/${DBs[${i}]}.${SUFFIX} )&
done
