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
      WHERE  usename = 'smartkidsagent') THEN

      CREATE ROLE smartkidsagent LOGIN
        ENCRYPTED PASSWORD 'md59cadc893a3a0c1135b10ebea6c13e9fe'
        NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION;

   END IF;
END
$body$;


CREATE DATABASE smartkidsdb
  WITH OWNER = smartkidsagent
       ENCODING = 'UTF8'
       TABLESPACE = pg_default
       LC_COLLATE = 'en_US.UTF-8'
       LC_CTYPE = 'en_US.UTF-8'
       CONNECTION LIMIT = -1;

\connect smartkidsdb

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
  msgcount integer NOT NULL DEFAULT 1,
  CONSTRAINT id_timestamp PRIMARY KEY (id, srv_ts)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE measures
  OWNER TO smartkidsagent;
