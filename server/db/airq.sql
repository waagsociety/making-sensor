--
-- PostgreSQL database dump
--

-- Dumped from database version 9.4.6
-- Dumped by pg_dump version 9.4.0
-- Started on 2016-04-07 15:38:22 CEST

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
      WHERE  usename = 'airqagent') THEN

      CREATE ROLE airqagent LOGIN
        ENCRYPTED PASSWORD 'md5bb10ec1348e0952788b8c2a169735bd3'
        NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION;

   END IF;
END
$body$;


CREATE DATABASE airq
  WITH OWNER = airqagent
       ENCODING = 'UTF8'
       TABLESPACE = pg_default
       LC_COLLATE = 'en_US.UTF-8'
       LC_CTYPE = 'en_US.UTF-8'
       CONNECTION LIMIT = -1;

\connect airq

CREATE TABLE IF NOT EXISTS measures
(
  id bigint NOT NULL DEFAULT (-1),
  srv_ts timestamp with time zone NOT NULL,
  topic text NOT NULL DEFAULT 'no topic'::text,
  rssi smallint,
  temp numeric,
  pm10 numeric,
  pm25 numeric,
  no2a numeric,
  no2b numeric,
  humidity numeric,
  message text,
  CONSTRAINT id_timestamp PRIMARY KEY (id, srv_ts)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE measures
  OWNER TO airqagent;

DROP TABLE IF EXISTS sensorparameters;

CREATE TABLE sensorparameters
(
  id bigint NOT NULL DEFAULT (-1),
  sensorname text,
  no2_offset numeric NOT NULL DEFAULT 0,
  no2_no2a_coeff numeric NOT NULL DEFAULT 0,
  no2_no2b_coeff numeric NOT NULL DEFAULT 0,
  no2_t_coeff numeric NOT NULL DEFAULT 0,
  no2_rh_coeff numeric NOT NULL DEFAULT 0,
  pm10_offset numeric NOT NULL DEFAULT 0,
  pm10_pm10_coeff numeric NOT NULL DEFAULT 0,
  pm10_pm25_coeff numeric NOT NULL DEFAULT 0,
  pm10_t_coeff numeric NOT NULL DEFAULT 0,
  pm10_rh_coeff numeric NOT NULL DEFAULT 0,
  pm25_offset numeric NOT NULL DEFAULT 0,
  pm25_pm25_coeff numeric NOT NULL DEFAULT 0,
  pm25_pm10_coeff numeric NOT NULL DEFAULT 0,
  pm25_t_coeff numeric NOT NULL DEFAULT 0,
  pm25_rh_coeff numeric NOT NULL DEFAULT 0,
  CONSTRAINT sensornames_id PRIMARY KEY (id)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE sensorparameters
  OWNER TO airqagent;


INSERT INTO sensorparameters VALUES (1184527, 'Ria voor', -948.330, 0.78882, -0.03145, 2.48056, -0.13649, -73.2166, -0.26322, 0.04061, 2.36435, 0.74739, -90.2196, 0.03483, -0.44703, 2.95294, 0.96549);
INSERT INTO sensorparameters VALUES (1184739, 'Gerrie', 334.814, 0.60572, -0.94631, 1.77077, 0.09940, -81.1249, -0.17391, 0.03372, 2.54902, 0.69391, -115.3868, 0.02329, -0.14975, 3.31781, 0.90699);
INSERT INTO sensorparameters VALUES (1183931, 'Pinto', -422.153, 0.64984, -0.33011, 2.22668, 0);
INSERT INTO sensorparameters VALUES (53788, 'Raymond', -395.371, 0.81885, -0.52675, 2.70356, 0.03442, -74.2242, -0.25424, 0.04835, 2.52225, 0.63249, -91.1616, 0.03708, -0.40018, 3.10339, 0.81896);
INSERT INTO sensorparameters VALUES (26296, 'Ria tuin', 43.860, 0.85933, -0.89710, 3.06853, 0.09517, -72.3332, -0.13611, 0.04069, 2.17743, 0.64897, -82.5863, 0.03656, -0.28036, 2.64449, 0.79051);
INSERT INTO sensorparameters VALUES (1184206, 'Clif', 517.992, 0.73030, -1.18645, -0.52342, 0.44390, -39.0560, -0.13715, 0.03271, 1.68117, 0.38462, -43.2467, 0.01928, -0.16337, 1.87083, 0.42680);
INSERT INTO sensorparameters VALUES (1185325, 'Frenk', -1112.031, 1.11992, -0.29661, 2.99670, -0.21242);
INSERT INTO sensorparameters VALUES (54200, 'Jet', -1568.040, 1.02914, 0.25044, 1.11659, -0.34655, -75.5985, -0.18217, 0.03849, 2.28203, 0.70210, -110.4794, 0.02943, -0.22328, 3.10821, 0.96624);
INSERT INTO sensorparameters VALUES (1184453, 'Puffi', -642.304, 0.75588, -0.27312, 3.43445, 0.03173, -81.0929, -0.12595, 0.03296, 2.49904, 0.64397, -99.6073, 0.02747, -0.17068, 3.16238, 0.70688);
INSERT INTO sensorparameters VALUES (717780, 'Paul', -634.290, 0.85252, -0.37971, 2.44669, -0.06876);
INSERT INTO sensorparameters VALUES (55303, 'GGD', -622.022, 0.88823, -0.36495, 2.15249, -0.00991, 3.9130, -0.14695, 0.03585, 0.36648, 3.91301, 6.6994, 0.03663, -0.30741, 0.49166, 6.69940);
INSERT INTO sensorparameters VALUES (55300, 'HelleLucht voor', -653.779, 0.81692, -0.35020, 2.85082, 0.05164, -85.7197, -0.23994, 0.03744, 2.48775, 0.87768, -107.6992, 0.02924, -0.27205, 3.05328, 1.00655);
INSERT INTO sensorparameters VALUES (13905017, 'Waag', 441.921, 0.20062, -0.59348, 2.41263, 0.39843);
INSERT INTO sensorparameters VALUES (14560051, 'Cuneke', 281.468, 0.44487, -0.73171, -0.48436, 0.42935, -57.2714, -0.22035, 0.03415, 1.82715, 0.61726, -80.0690, 0.02939, -0.27738, 2.46952, 0.75162);
INSERT INTO sensorparameters VALUES (1184838, 'Pieter', 511.997, 0.88222, -1.38903, 4.12857, 0.50768, -76.4428, -0.28846, 0.05334, 2.48589, 0.93975, -91.4543, 0.03679, -0.33789, 2.87518, 1.10880);
INSERT INTO sensorparameters VALUES (54911, 'HelleLucht achter', -889.854, 0.94064, -0.26633, 2.85066, 0.00686,  -62.297, -0.17863, 0.03541, 2.05071, 0.65088, -84.1375, 0.02599, -0.18892, 2.63943, 0.74354);


DO
$body$
BEGIN
   IF NOT EXISTS (
      SELECT *
      FROM   pg_catalog.pg_user
      WHERE  usename = 'trafficagent') THEN

      CREATE ROLE trafficagent LOGIN
        ENCRYPTED PASSWORD 'md5d76679c3f866741317ca56016448d19a'
        NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION;

   END IF;
END
$body$;


CREATE DATABASE traffic
  WITH OWNER = trafficagent
       ENCODING = 'UTF8'
       TABLESPACE = pg_default
       LC_COLLATE = 'en_US.UTF-8'
       LC_CTYPE = 'en_US.UTF-8'
       CONNECTION LIMIT = -1;

\connect traffic

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;

CREATE TABLE IF NOT EXISTS traveltime
(
  id character varying(100) NOT NULL,
  name character varying(100) NOT NULL,
  type character varying(10) NOT NULL,
  timestmp timestamp with time zone NOT NULL,
  length integer NOT NULL,
  traveltime integer,
  velocity integer,
  coordinates geometry NOT NULL,
  CONSTRAINT id_timestamp PRIMARY KEY (id, timestmp)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE traveltime
  OWNER TO trafficagent;
