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

DROP TABLE IF EXISTS sensornames;

CREATE TABLE sensornames
(
  id bigint NOT NULL DEFAULT (-1),
  sensorname text,
  CONSTRAINT sensornames_id PRIMARY KEY (id)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE sensornames
  OWNER TO airqagent;

INSERT INTO sensornames (id, sensorname) VALUES (26296, 'Ria tuin');
INSERT INTO sensornames (id, sensorname) VALUES (53788, 'Raymond');
INSERT INTO sensornames (id, sensorname) VALUES (54200, 'Jet');
INSERT INTO sensornames (id, sensorname) VALUES (54911, 'Maarten achter');
INSERT INTO sensornames (id, sensorname) VALUES (55300, 'Maarten voor');
INSERT INTO sensornames (id, sensorname) VALUES (55303, 'GGD');
INSERT INTO sensornames (id, sensorname) VALUES (717780, 'Paul');
INSERT INTO sensornames (id, sensorname) VALUES (1183931, 'Pinto');
INSERT INTO sensornames (id, sensorname) VALUES (1184206, 'Clif');
INSERT INTO sensornames (id, sensorname) VALUES (1184453, 'Puffi');
INSERT INTO sensornames (id, sensorname) VALUES (1184527, 'Ria voor');
INSERT INTO sensornames (id, sensorname) VALUES (1184739, 'Gerrie');
INSERT INTO sensornames (id, sensorname) VALUES (1184838, 'Pieter');
INSERT INTO sensornames (id, sensorname) VALUES (1185325, 'Frenk');
INSERT INTO sensornames (id, sensorname) VALUES (13905017, 'Waag');
INSERT INTO sensornames (id, sensorname) VALUES (14560051, 'Cuneke');


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
