/*
 * Copyright (C) 2011-2014 C/W MARS.
 * Created by Tim Spindler
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 */
-- To run: psql -f AMC_student_load.sql -v file=/absolute/path/to/datafile
-- Other options omitted for brevity.

 /*Verify in the data file that the home library matches the org unit in name
  *Verify that the permission group matches and existing permission group
  *Verify the data format and use the appropriate line below
  */

TRUNCATE staging.student_load;

--Libraries need to provide a tabbed delimited file with.
\COPY staging.student_load (library, first_given_name, second_given_name, family_name, barcode, usrname, passwd, ident_value, local_street1, local_street2, local_city, local_state, local_post_code, home_street1, home_street2, home_city, home_state, home_post_code, local_telephone, home_telephone, email, dob, expire_date, permission_group, gender, stat_cat1, stat_cat2) FROM '/home/opensrf/AMC_patrons.txt';

--Normalizes the data
DELETE FROM staging.student_load WHERE first_given_name~*'(first_given_name)' AND second_given_name~*'(second_given_name)';
UPDATE staging.student_load SET ident_value = TRIM(ident_value)||'AN' WHERE ident_value!~'(AN)';
UPDATE staging.student_load SET home_telephone=SUBSTRING(home_telephone,1,3)||'-'||SUBSTRING(home_telephone,4,3)||'-'||SUBSTRING(home_telephone,7,4) WHERE home_telephone~'[0-9]{10}';
UPDATE staging.student_load SET local_telephone=SUBSTRING(local_telephone,1,3)||'-'||SUBSTRING(local_telephone,4,3)||'-'||SUBSTRING(local_telephone,7,4) WHERE local_telephone~'[0-9]{10}';
UPDATE staging.student_load SET home_telephone=regexp_replace((regexp_replace(home_telephone, E'\\)','-')),E'\\(','') WHERE home_telephone~E'\\([0-9]{3}\\)[0-9]{3}-[0-9]{4}';
UPDATE staging.student_load SET local_telephone=regexp_replace((regexp_replace(local_telephone, E'\\)','-')),E'\\(','') WHERE local_telephone~E'\\([0-9]{3}\\)[0-9]{3}-[0-9]{4}';
UPDATE staging.student_load SET home_telephone=NULL WHERE home_telephone!~E'^([0-9]{3}-?[0-9]{3}-?[0-9]{4,10})$';
UPDATE staging.student_load SET local_telephone=NULL WHERE local_telephone!~E'^([0-9]{3}-?[0-9]{3}-?[0-9]{4,10})$';
UPDATE staging.student_load SET dob=NULL WHERE dob!~'([0-9])';
UPDATE staging.student_load SET library='AMC Mondor-Eagen Library';
UPDATE staging.student_load SET permission_group='Anna Maria Student' FROM permission.grp_tree gt WHERE student_load.permission_group=gt.name AND gt.parent!=19;
UPDATE staging.student_load SET gender='male' WHERE gender~*'^m';
UPDATE staging.student_load SET gender='female' WHERE gender~*'^f';
UPDATE staging.student_load SET first_given_name=UPPER(first_given_name), second_given_name=UPPER(second_given_name), family_name=UPPER(family_name),
	local_street1=UPPER(local_street1), local_street2=UPPER(local_street2), local_city=UPPER(local_city), local_state=UPPER(local_state),
	home_street1=UPPER(home_street1), home_street2=UPPER(home_street2), home_city=UPPER(home_city), home_state=UPPER(home_state);


--Update existing records matching on ident_value
BEGIN;

UPDATE staging.student_load SET usr=u.id FROM actor.usr AS u WHERE student_load.ident_value=u.ident_value;
UPDATE actor.usr SET first_given_name=s.first_given_name, second_given_name=s.second_given_name, family_name=s.family_name, ident_type=1 FROM staging.student_load AS s WHERE usr.id=s.usr;
UPDATE actor.usr SET profile=t.id FROM staging.student_load AS s INNER JOIN permission.grp_tree t ON UPPER(s.permission_group)=UPPER(t.name) WHERE usr.id=s.usr AND s.permission_group IS NOT NULL;
UPDATE actor.usr SET day_phone=s.local_telephone FROM staging.student_load AS s WHERE usr.id=s.usr AND s.local_telephone IS NOT NULL;
UPDATE actor.usr SET other_phone=s.home_telephone FROM staging.student_load AS s WHERE usr.id=s.usr AND s.home_telephone IS NOT NULL;
UPDATE actor.usr SET email=s.email FROM staging.student_load AS s WHERE usr.id=s.usr AND s.email IS NOT NULL;
UPDATE actor.usr SET dob=date(s.dob) FROM staging.student_load AS s WHERE usr.id=s.usr AND s.dob IS NOT NULL;
UPDATE actor.usr SET expire_date=date(s.expire_date) FROM staging.student_load AS s WHERE usr.id=s.usr AND s.expire_date IS NOT NULL;
--This only inserts address of it is not already in the system.  The old address will remain but these will replace mailing and billing address
INSERT INTO actor.usr_address (valid, within_city_limits, address_type, usr, street1, street2, city, state, country, post_code)
	SELECT TRUE, FALSE, 'home address', s.usr, UPPER(home_street1), UPPER(home_street2), UPPER(home_city), UPPER(home_state), 'USA', home_post_code
	FROM staging.student_load s LEFT JOIN actor.usr_address u ON s.usr=u.usr AND UPPER(s.home_street1)=UPPER(u.street1) AND UPPER(s.home_city)=UPPER(u.city) AND s.home_post_code=u.post_code
	WHERE s.usr is not null AND s.home_street1 ~*'([a-z|0-9])' AND u.id IS NULL;
INSERT INTO actor.usr_address (valid, within_city_limits, address_type, usr, street1, street2, city, state, country, post_code)
	SELECT TRUE, FALSE, 'local address', s.usr, UPPER(local_street1), UPPER(local_street2), UPPER(local_city), UPPER(local_state), 'USA', local_post_code
	FROM staging.student_load s LEFT JOIN actor.usr_address u ON s.usr=u.usr AND UPPER(s.local_street1)=UPPER(u.street1) AND UPPER(s.local_city)=UPPER(u.city) AND s.local_post_code=u.post_code
	WHERE s.usr IS NOT NULL AND s.local_street1 ~*'([a-z|0-9])' AND u.id IS NULL;
UPDATE actor.usr SET mailing_address=u.id, billing_address=u.id FROM actor.usr_address AS u INNER JOIN staging.student_load AS s ON s.usr=u.usr AND s.local_street1=u.street1 AND s.local_post_code=u.post_code AND s.local_state=u.state WHERE usr.id=u.usr AND s.local_city IS NOT NULL;
UPDATE actor.usr SET mailing_address=u.id, billing_address=u.id FROM actor.usr_address AS u INNER JOIN staging.student_load AS s ON s.usr=u.usr AND s.home_street1=u.street1 AND s.home_post_code=u.post_code AND s.home_state=u.state WHERE usr.id=u.usr AND s.home_city~*'([a-z|0-9])' AND usr.mailing_address IS NULL;
INSERT INTO actor.card (usr, barcode, active) SELECT s.usr, s.barcode, 'TRUE' FROM staging.student_load s LEFT JOIN actor.card c ON s.barcode=c.barcode  WHERE c.usr IS NULL AND s.usr IS NOT NULL AND s.barcode~'([0-9])';
INSERT INTO actor.card (usr, barcode, active) SELECT s.usr, s.ident_value, 'TRUE' FROM staging.student_load s LEFT JOIN actor.card c ON s.ident_value=c.barcode WHERE s.usr IS NOT NULL AND c.barcode IS NULL;
UPDATE staging.student_load SET card=c.id FROM actor.card c WHERE student_load.usr=c.usr AND c.barcode~'([0-9]$)';
UPDATE staging.student_load SET card=c.id FROM actor.card c WHERE student_load.usr=c.usr AND student_load.card IS NULL;
UPDATE actor.usr SET card=s.card FROM staging.student_load s WHERE usr.id=s.usr AND usr.card IS NULL;
DELETE FROM actor.stat_cat_entry_usr_map m WHERE stat_cat=1 AND m.target_usr in (SELECT usr FROM staging.student_load WHERE gender IS NOT NULL);
INSERT INTO actor.stat_cat_entry_usr_map (stat_cat_entry, stat_cat, target_usr) SELECT lower(s.gender), e.stat_cat, s.usr FROM staging.student_load s JOIN actor.stat_cat_entry e ON lower(s.gender)=e.value WHERE s.usr IS NOT NULL AND s.gender IS NOT NULL;
UPDATE staging.student_load SET stat_cat1 = NULL WHERE usr in (SELECT s.usr FROM staging.student_load s LEFT JOIN actor.stat_cat_entry e ON s.stat_cat1=e.value WHERE s.stat_cat1 IS NOT NULL AND e.value IS NULL);
UPDATE staging.student_load SET stat_cat1 = NULL WHERE usr in (SELECT s.usr FROM staging.student_load s LEFT JOIN actor.stat_cat_entry e ON s.stat_cat2=e.value WHERE s.stat_cat2 IS NOT NULL AND e.value IS NULL);
DELETE FROM actor.stat_cat_entry_usr_map m WHERE m.id in (SELECT DISTINCT m.id FROM actor.stat_cat_entry_usr_map m JOIN actor.stat_cat_entry e ON e.value=m.stat_cat_entry JOIN staging.student_load s ON e.value=s.stat_cat1 WHERE s.stat_cat1 IS NOT NULL);
INSERT INTO actor.stat_cat_entry_usr_map (stat_cat_entry, stat_cat, target_usr) SELECT s.stat_cat1, e.stat_cat, s.usr FROM staging.student_load s JOIN actor.stat_cat_entry e ON s.stat_cat1=e.value WHERE s.usr IS NOT NULL AND s.stat_cat1 IS NOT NULL;
DELETE FROM actor.stat_cat_entry_usr_map m WHERE m.id in (SELECT DISTINCT m.id FROM actor.stat_cat_entry_usr_map m JOIN actor.stat_cat_entry e ON e.value=m.stat_cat_entry JOIN staging.student_load s ON e.value=s.stat_cat2 WHERE s.stat_cat2 IS NOT NULL);
INSERT INTO actor.stat_cat_entry_usr_map (stat_cat_entry, stat_cat, target_usr) SELECT s.stat_cat2, e.stat_cat, s.usr FROM staging.student_load s JOIN actor.stat_cat_entry e ON s.stat_cat2=e.value WHERE s.usr IS NOT NULL AND s.stat_cat2 IS NOT NULL;
INSERT INTO staging.student_load_log (org_unit, type, count) SELECT 4,'UPDATED', count(usr) FROM staging.student_load WHERE usr IS NOT NULL;
DELETE FROM staging.student_load WHERE usr IS NOT NULL;

COMMIT;

--Create new records when no match on ident_value
BEGIN;

UPDATE staging.student_load SET usrname=ident_value WHERE usrname !~*'([0-9|a-z])';
UPDATE staging.student_load SET passwd=UPPER(family_name) WHERE passwd !~*'([a-z|0-9])';
UPDATE staging.student_load SET barcode=ident_value WHERE barcode !~*'([0-9|a-z])';
UPDATE staging.student_load SET do_not_load=TRUE FROM actor.usr u WHERE student_load.usrname=u.usrname;
INSERT INTO staging.student_load_log (type, count, org_unit, description) SELECT 'not loaded', count(l.ident_value), 4, 'usrname already exists' FROM staging.student_load l JOIN actor.usr u ON l.usrname=u.usrname;
UPDATE staging.student_load SET do_not_load=TRUE FROM actor.card c WHERE student_load.barcode=c.barcode;
INSERT INTO staging.student_load_log (type, count, org_unit, description) SELECT 'not loaded', count(l.ident_value), 4, 'barcode already exists' FROM staging.student_load l JOIN actor.usr u ON l.usrname=u.usrname;

INSERT INTO actor.usr (first_given_name, second_given_name, family_name, usrname, passwd, day_phone, other_phone, email, dob, expire_date, standing, ident_type, ident_value, net_access_level, profile, home_ou)
	SELECT s.first_given_name, s.second_given_name, s.family_name, s.usrname, s.passwd, s.local_telephone, s.home_telephone, s.email, date(s.dob), date(s.expire_date), 1, 1, s.ident_value, 2, t.id, o.id FROM staging.student_load s JOIN permission.grp_tree t ON UPPER(s.permission_group) = UPPER(t.name) JOIN actor.org_unit  o ON UPPER(s.library)=UPPER(o.name)
	WHERE s.usr is null AND do_not_load=FALSE;
UPDATE staging.student_load SET usr=u.id FROM actor.usr as u WHERE student_load.ident_value=u.ident_value;
INSERT INTO actor.usr_address (valid, within_city_limits, address_type, usr, street1, street2, city, state, country, post_code)
	SELECT TRUE, FALSE, 'home address', s.usr, UPPER(home_street1), UPPER(home_street2), UPPER(home_city), UPPER(home_state), 'USA', home_post_code
	FROM staging.student_load s WHERE home_street1~*'([a-z|0-9])' AND do_not_load=FALSE;
INSERT INTO actor.usr_address (valid, within_city_limits, address_type, usr, street1, street2, city, state, country, post_code)
	SELECT TRUE, FALSE, 'local address', s.usr, UPPER(local_street1), UPPER(local_street2), UPPER(local_city), UPPER(local_state), 'USA', local_post_code
	FROM staging.student_load s WHERE local_street1~*'([a-z|0-9])' AND do_not_load=FALSE;
UPDATE actor.usr SET mailing_address=u.id, billing_address=u.id FROM actor.usr_address AS u JOIN staging.student_load AS s ON s.usr=u.usr AND s.local_street1=u.street1 AND s.local_post_code=u.post_code AND s.local_state=u.state WHERE usr.id=u.usr AND s.local_city~*'([a-z|0-9])';;
UPDATE actor.usr SET mailing_address=u.id, billing_address=u.id FROM actor.usr_address AS u JOIN staging.student_load AS s ON s.usr=u.usr AND s.home_street1=u.street1 AND s.home_post_code=u.post_code AND s.home_state=u.state WHERE usr.id=u.usr AND s.home_city~*'([a-z|0-9])' AND usr.mailing_address IS NULL;
INSERT INTO actor.card (usr, barcode, active) SELECT s.usr, s.barcode, 'TRUE' FROM staging.student_load s LEFT JOIN actor.card c ON s.barcode=c.barcode  WHERE c.usr IS NULL AND s.barcode~'([0-9])' AND do_not_load=FALSE;
INSERT INTO actor.card (usr, barcode, active) SELECT s.usr, s.ident_value, 'TRUE' FROM staging.student_load s LEFT JOIN actor.card c ON s.ident_value=c.barcode WHERE c.id IS NULL AND do_not_load=FALSE;
UPDATE staging.student_load SET card=c.id FROM actor.card c WHERE student_load.usr=c.usr AND c.barcode~'([0-9]$)';
UPDATE staging.student_load SET card=c.id FROM actor.card c WHERE student_load.usr=c.usr AND student_load.card IS NULL;
UPDATE actor.usr SET card=s.card FROM staging.student_load s WHERE usr.id=s.usr AND usr.card IS NULL;
INSERT INTO actor.stat_cat_entry_usr_map (stat_cat_entry, stat_cat, target_usr)
	SELECT lower(s.gender), e.stat_cat, s.usr FROM staging.student_load s JOIN actor.stat_cat_entry e ON s.gender=e.value WHERE s.usr IS NOT NULL AND s.gender IS NOT NULL AND do_not_load=FALSE;
UPDATE staging.student_load SET stat_cat1 = NULL WHERE usr in (SELECT s.usr FROM staging.student_load s LEFT JOIN actor.stat_cat_entry e ON s.stat_cat1=e.value WHERE s.stat_cat1 IS NOT NULL AND e.value IS NULL);
UPDATE staging.student_load SET stat_cat1 = NULL WHERE usr in (SELECT s.usr FROM staging.student_load s LEFT JOIN actor.stat_cat_entry e ON s.stat_cat2=e.value WHERE s.stat_cat2 IS NOT NULL AND e.value IS NULL);
INSERT INTO actor.stat_cat_entry_usr_map (stat_cat_entry, stat_cat, target_usr)
	SELECT s.stat_cat1, e.stat_cat, s.usr FROM staging.student_load s JOIN actor.stat_cat_entry e ON s.stat_cat1=e.value WHERE s.usr IS NOT NULL AND s.stat_cat1 IS NOT NULL AND do_not_load=FALSE;
INSERT INTO actor.stat_cat_entry_usr_map (stat_cat_entry, stat_cat, target_usr)
	SELECT s.stat_cat2, e.stat_cat, s.usr FROM staging.student_load s JOIN actor.stat_cat_entry e ON s.stat_cat2=e.value WHERE s.usr IS NOT NULL AND s.stat_cat2 IS NOT NULL;
INSERT INTO staging.student_load_log (org_unit, type, count) SELECT 4,'CREATED', count(usr) FROM staging.student_load WHERE usr IS NOT NULL AND do_not_load=FALSE;
DELETE FROM staging.student_load WHERE usr IS NOT NULL;

COMMIT;

SELECT 1 as seq, created::text, type, count::text, description FROM staging.student_load_log WHERE org_unit=4 AND created>=DATE(NOW())
UNION
SELECT 2 as seq, '----','----','----','-----'
UNION
SELECT 3 as seq, 'Students Not Loaded','----','----','-----'
UNION
SELECT 4 as seq, '----','----','----','-----'
UNION
SELECT 5 as seq, ident_value, first_given_name, family_name, email FROM staging.student_load
ORDER BY seq, created;
