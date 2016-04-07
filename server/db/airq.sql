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

CREATE ROLE airqagent LOGIN
  ENCRYPTED PASSWORD 'md5bb10ec1348e0952788b8c2a169735bd3'
  NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION;

--
-- TOC entry 2035 (class 1262 OID 16385)
-- Name: airq; Type: DATABASE; Schema: -; Owner: airqagent
--

CREATE DATABASE airq WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8';


ALTER DATABASE airq OWNER TO airqagent;

\connect airq

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- TOC entry 5 (class 2615 OID 2200)
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO postgres;

--
-- TOC entry 2036 (class 0 OID 0)
-- Dependencies: 5
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- TOC entry 173 (class 3079 OID 11893)
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner:
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- TOC entry 2038 (class 0 OID 0)
-- Dependencies: 173
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner:
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- TOC entry 172 (class 1259 OID 16397)
-- Name: measures; Type: TABLE; Schema: public; Owner: airqagent; Tablespace:
--

-- Table: measures

-- DROP TABLE measures;

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
  CONSTRAINT id_timestamp PRIMARY KEY (id, srv_ts)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE measures
  OWNER TO airqagent;


--
-- TOC entry 2037 (class 0 OID 0)
-- Dependencies: 5
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


-- Completed on 2016-04-07 15:38:23 CEST

--
-- PostgreSQL database dump complete
--
