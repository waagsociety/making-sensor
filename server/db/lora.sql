--
-- PostgreSQL database dump
--


SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;


CREATE SCHEMA IF NOT EXISTS public;

ALTER SCHEMA public OWNER TO postgres;

COMMENT ON SCHEMA public IS 'standard public schema';

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;

DO
$body$
BEGIN
   IF NOT EXISTS (
      SELECT *
      FROM   pg_catalog.pg_user
      WHERE  usename = 'loraagent') THEN

      CREATE ROLE loraagent LOGIN
        ENCRYPTED PASSWORD 'md5e05c126d95be1744ac379db2df0fd8a2'
        NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION;

   END IF;
END
$body$;


CREATE DATABASE loradb
  WITH OWNER = loraagent
       ENCODING = 'UTF8'
       TABLESPACE = pg_default
       LC_COLLATE = 'en_US.UTF-8'
       LC_CTYPE = 'en_US.UTF-8'
       CONNECTION LIMIT = -1;

\connect loradb

-- {
-- "payload": "MzIzMgnELwILxMQA",
-- "fields": {
--   "hum": 47,
--   "op1": 13106,
--   "op2": 13106,
--   "pm10": 50372,
--   "pm25": 523,
--   "temp": 25
-- },
-- "port": 1,
-- "counter": 15,
-- "dev_eui": "000000004D8D3F94",
-- "metadata": [
--   {
--     "frequency": 867.7,
--     "datarate": "SF7BW125",
--     "codingrate": "4/5",
--     "gateway_timestamp": 1492507156,
--     "channel": 7,
--     "server_time": "2016-11-01T14:01:42.128849779Z",
--     "rssi": -73,
--     "lsnr": 9.2,
--     "rfchain": 0,
--     "crc": 1,
--     "modulation": "LORA",
--     "gateway_eui": "0000024B08060030",
--     "altitude": 16,
--     "longitude": 4.90036,
--     "latitude": 52.37283
--   }

CREATE TABLE IF NOT EXISTS measures
(
  payload VARCHAR(18),
  port smallint,
  counter bigint NOT NULL,
  dev_eui VARCHAR(18) NOT NULL,
  frequency numeric,
  datarate VARCHAR(10),
  codingrate VARCHAR(5),
  gateway_timestamp bigint,
  channel smallint,
  server_time timestamp with time zone NOT NULL,
  rssi smallint,
  lsnr numeric,
  rfchain smallint,
  crc smallint,
  modulation text,
  gateway_eui VARCHAR(18) NOT NULL,
  altitude numeric,
  longitude numeric,
  latitude numeric,
  no2a numeric,
  no2b numeric,
  pm25 numeric,
  pm10 numeric,
  temp numeric,
  humidity numeric,
  CONSTRAINT dev_eui_server_time PRIMARY KEY (dev_eui, server_time)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE measures
  OWNER TO loraagent;
