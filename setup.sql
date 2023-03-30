--
-- PostgreSQL database dump
--

-- Dumped from database version 10.23 (Ubuntu 10.23-1.pgdg22.04+1)
-- Dumped by pg_dump version 15.2 (Ubuntu 15.2-1.pgdg20.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

--
-- Name: student_load; Type: TABLE; Schema: staging; Owner: evergreen
--

CREATE TABLE staging.student_load (
    library text,
    first_given_name text,
    second_given_name text,
    family_name text,
    barcode text,
    usrname text,
    passwd text,
    ident_value text,
    local_street1 text,
    local_street2 text,
    local_city text,
    local_state text,
    local_post_code text,
    home_street1 text,
    home_street2 text,
    home_city text,
    home_state text,
    home_post_code text,
    home_telephone text,
    local_telephone text,
    email text,
    dob text,
    expire_date text,
    permission_group text,
    gender text,
    stat_cat1 text,
    stat_cat2 text,
    usr bigint,
    card bigint,
    do_not_load boolean DEFAULT false,
    pref_first_given_name text,
    pref_second_given_name text,
    pref_family_name text
);


ALTER TABLE staging.student_load OWNER TO evergreen;

--
-- Name: student_load_log; Type: TABLE; Schema: staging; Owner: evergreen
--

CREATE TABLE staging.student_load_log (
    id bigint NOT NULL,
    created timestamp with time zone DEFAULT now(),
    type text,
    count integer,
    org_unit integer,
    description text
);


ALTER TABLE staging.student_load_log OWNER TO evergreen;

--
-- Name: student_load_log_id_seq; Type: SEQUENCE; Schema: staging; Owner: evergreen
--

CREATE SEQUENCE staging.student_load_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE staging.student_load_log_id_seq OWNER TO evergreen;

--
-- Name: student_load_log_id_seq; Type: SEQUENCE OWNED BY; Schema: staging; Owner: evergreen
--

ALTER SEQUENCE staging.student_load_log_id_seq OWNED BY staging.student_load_log.id;


--
-- Name: student_load_log id; Type: DEFAULT; Schema: staging; Owner: evergreen
--

ALTER TABLE ONLY staging.student_load_log ALTER COLUMN id SET DEFAULT nextval('staging.student_load_log_id_seq'::regclass);


--
-- Name: staging_student_load_ident_val; Type: INDEX; Schema: staging; Owner: evergreen
--

CREATE INDEX staging_student_load_ident_val ON staging.student_load USING btree (ident_value);


--
-- PostgreSQL database dump complete
--

