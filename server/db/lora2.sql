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


CREATE DATABASE lora2db
  WITH OWNER = loraagent
       ENCODING = 'UTF8'
       TABLESPACE = pg_default
       LC_COLLATE = 'en_US.UTF-8'
       LC_CTYPE = 'en_US.UTF-8'
       CONNECTION LIMIT = -1;

\connect lora2db

-- {
--   "app_id": "makingsense",
--   "dev_id": "boralorawest",
--   "hardware_serial": "00000000985A5569",
--   "port": 1,
--   "counter": 1586,
--   "payload_raw": "BMcFTAfQJQECAAAA",
--   "payload_fields": {
--     "hum": 37,
--     "op1": 1223,
--     "op2": 1356,
--     "pm10": 0,
--     "pm25": 258,
--     "temp": 20
--   },
--   "metadata": {
--     "time": "2017-04-05T14:24:30.097582156Z",
--     "frequency": 868.5,
--     "modulation": "LORA",
--     "data_rate": "SF7BW125",
--     "coding_rate": "4\/5",
--     "gateways": [
--       {
--         "gtw_id": "eui-0000024b08060712",
--         "timestamp": 4157431915,
--         "time": "",
--         "channel": 2,
--         "rssi": -57,
--         "snr": 8,
--         "rf_chain": 1,
--         "latitude": 52.36936,
--         "longitude": 4.8623486
--       }
--     ]
--   }
-- }



CREATE TABLE IF NOT EXISTS measures
(
    app_id character varying(18) COLLATE pg_catalog."default",
    dev_id character varying(18) COLLATE pg_catalog."default" NOT NULL,
    hardware_serial character varying(18) COLLATE pg_catalog."default",
    port smallint,
    counter bigint NOT NULL,
    payload_raw character varying(18) COLLATE pg_catalog."default",
    no2a numeric,
    no2b numeric,
    pm25 numeric,
    pm10 numeric,
    temp numeric,
    humidity numeric,
    server_time timestamp with time zone NOT NULL,
    frequency numeric,
    modulation text COLLATE pg_catalog."default",
    data_rate character varying(10) COLLATE pg_catalog."default",
    coding_rate character varying(5) COLLATE pg_catalog."default",
    gateways jsonb,
    CONSTRAINT dev_id_server_time PRIMARY KEY (dev_id, server_time)
)
WITH (
    OIDS = FALSE
)
TABLESPACE pg_default;

ALTER TABLE public.measures
    OWNER to loraagent;
