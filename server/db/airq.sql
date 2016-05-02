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


CREATE SCHEMA public;

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

CREATE ROLE airqagent LOGIN
  ENCRYPTED PASSWORD 'md5bb10ec1348e0952788b8c2a169735bd3'
  NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION;


CREATE DATABASE airq
  WITH OWNER = airqagent
       ENCODING = 'UTF8'
       TABLESPACE = pg_default
       LC_COLLATE = 'en_US.UTF-8'
       LC_CTYPE = 'en_US.UTF-8'
       CONNECTION LIMIT = -1;

\connect airq

CREATE TABLE measures
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


CREATE ROLE trafficagent LOGIN
  ENCRYPTED PASSWORD 'md5d76679c3f866741317ca56016448d19a'
  NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION;


CREATE DATABASE traffic
  WITH OWNER = trafficagent
       ENCODING = 'UTF8'
       TABLESPACE = pg_default
       LC_COLLATE = 'en_US.UTF-8'
       LC_CTYPE = 'en_US.UTF-8'
       CONNECTION LIMIT = -1;

\connect traffic

CREATE EXTENSION postgis;
CREATE EXTENSION postgis_topology;

CREATE TABLE traveltime
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
