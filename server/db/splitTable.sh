if date -j >/dev/null 2>&1
then
  FROM_TIME="$(date -v-1d '+%F 12:00:00+0000')"
else
  FROM_TIME="$(date '+%Y-%m-%d 12:00:00+0000' -d '1 day ago')"
fi

STR_FROMTIME=$(echo ${FROM_TIME} | tr '-' '_' | tr ' ' '_' | tr ':' '_' | tr '+' '_')

echo "
CREATE TABLE traveltime_${STR_FROMTIME}
(
  id character varying(100) NOT NULL,
  name character varying(100) NOT NULL,
  type character varying(10) NOT NULL,
  timestmp timestamp with time zone NOT NULL,
  length integer NOT NULL,
  traveltime integer,
  velocity integer,
  coordinates geometry NOT NULL
  --, CONSTRAINT id_timestamp_${STR_FROMTIME} PRIMARY KEY (id, timestmp)
)
WITH (
  OIDS=FALSE
);
-- ALTER TABLE traveltime_${STR_FROMTIME}
--   OWNER TO trafficagent;


WITH moved_rows AS (
    DELETE FROM traveltime
    WHERE
        timestmp < '${FROM_TIME}'
    RETURNING *
)
INSERT INTO traveltime_${STR_FROMTIME}
SELECT * FROM moved_rows;
" | sudo su postgres -c 'psql traffic'
