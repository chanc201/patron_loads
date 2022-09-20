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

 /*Verify in the data file that the home library matches the org unit in name
  *Verify that the permission group matches and existing permission group
  *Verify the data format and use the appropriate line below
  */

 /*
 Because of our transition to a new student information system, we have had to make some changes in how our patron loads
 are completed. For this patron load, please overwrite the following fields:

*         Barcode
*         Username
*         Password

Do not overwrite the unique ID field, and continue to match on unique ID.
In a future patron load we will need to overwrite unique ID's.

Michael Mannheim
* Libraries need to provide a tabbed delimited file with.

*/


TRUNCATE staging.student_load;

\COPY staging.student_load (library, first_given_name, second_given_name, family_name, barcode, usrname, passwd, ident_value, local_street1, local_street2, local_city, local_state, local_post_code, home_street1, home_street2, home_city, home_state, home_post_code, local_telephone, home_telephone, email, dob, expire_date, permission_group, gender, stat_cat1, stat_cat2) FROM '/home/opensrf/patron_loads/student_data/AIC_patrons.txt';

--Normalizes the data
DELETE FROM staging.student_load WHERE first_given_name~*'(first_given_name)' AND second_given_name~*'(second_given_name)';
UPDATE staging.student_load SET ident_value = TRIM(ident_value)||'AI' WHERE ident_value!~'(AI)';
UPDATE staging.student_load SET home_telephone=SUBSTRING(home_telephone,1,3)||'-'||SUBSTRING(home_telephone,4,3)||'-'||SUBSTRING(home_telephone,7,4) WHERE home_telephone~'[0-9]{10}';
UPDATE staging.student_load SET local_telephone=SUBSTRING(local_telephone,1,3)||'-'||SUBSTRING(local_telephone,4,3)||'-'||SUBSTRING(local_telephone,7,4) WHERE local_telephone~'[0-9]{10}';
UPDATE staging.student_load SET home_telephone=regexp_replace((regexp_replace(home_telephone, E'\\)','-')),E'\\(','') WHERE home_telephone~E'\\([0-9]{3}\\)[0-9]{3}-[0-9]{4}';
UPDATE staging.student_load SET local_telephone=regexp_replace((regexp_replace(local_telephone, E'\\)','-')),E'\\(','') WHERE local_telephone~E'\\([0-9]{3}\\)[0-9]{3}-[0-9]{4}';
UPDATE staging.student_load SET home_telephone=NULL WHERE home_telephone!~E'^([0-9]{3}-?[0-9]{3}-?[0-9]{4,10})$';
UPDATE staging.student_load SET local_telephone=NULL WHERE local_telephone!~E'^([0-9]{3}-?[0-9]{3}-?[0-9]{4,10})$';
UPDATE staging.student_load SET dob=NULL WHERE dob!~'([0-9])';
UPDATE staging.student_load SET library='AIC Shea Library';
UPDATE staging.student_load SET permission_group='AIC UNDERGRADUATE' FROM permission.grp_tree gt WHERE student_load.permission_group=gt.name AND gt.parent!=19;
UPDATE staging.student_load SET gender='male' WHERE gender~*'^m';
UPDATE staging.student_load SET gender='female' WHERE gender~*'^f';
UPDATE staging.student_load SET first_given_name=UPPER(first_given_name), second_given_name=UPPER(second_given_name), family_name=UPPER(family_name),
	local_street1=UPPER(local_street1), local_street2=UPPER(local_street2), local_city=UPPER(local_city), local_state=UPPER(local_state),
	home_street1=UPPER(home_street1), home_street2=UPPER(home_street2), home_city=UPPER(home_city), home_state=UPPER(home_state);


--Update existing records matching on ident_value
BEGIN;

UPDATE staging.student_load SET usr=u.id FROM actor.usr AS u WHERE student_load.ident_value=u.ident_value;
UPDATE actor.usr SET profile=t.id FROM staging.student_load AS s INNER JOIN permission.grp_tree t ON UPPER(s.permission_group)=UPPER(t.name) WHERE usr.id=s.usr AND s.permission_group IS NOT NULL;
UPDATE actor.usr SET expire_date=date(s.expire_date), ident_type=1 FROM staging.student_load AS s WHERE usr.id=s.usr AND s.expire_date IS NOT NULL;

INSERT INTO staging.student_load_log (org_unit, type, count) SELECT 152, 'UPDATED', count(usr) FROM staging.student_load WHERE usr IS NOT NULL;
DELETE from STAGING.STUDENT_LOAD where USR IS NOT NULL;
COMMIT;

--Create new records when no match on ident_value
BEGIN;

UPDATE staging.student_load SET usrname=ident_value WHERE usrname !~*'([0-9|a-z])';
UPDATE staging.student_load SET passwd=UPPER(family_name) WHERE passwd !~*'([a-z|0-9])';
UPDATE staging.student_load SET barcode=ident_value WHERE barcode !~*'([0-9|a-z])';
UPDATE staging.student_load SET do_not_load=TRUE FROM actor.usr u WHERE student_load.usrname=u.usrname;
INSERT INTO staging.student_load_log (type, count, org_unit, description) SELECT 'not loaded', count(l.ident_value), 152, 'usrname already exists' FROM staging.student_load l JOIN actor.usr u ON l.usrname=u.usrname;
UPDATE staging.student_load SET do_not_load=TRUE FROM actor.card c WHERE student_load.barcode=c.barcode;
INSERT INTO staging.student_load_log (type, count, org_unit, description) SELECT 'not loaded', count(l.ident_value), 152, 'barcode already exists' FROM staging.student_load l JOIN actor.usr u ON l.usrname=u.usrname;

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

INSERT INTO actor.card (usr, barcode, active) SELECT s.usr, s.barcode, 'TRUE' FROM staging.student_load s WHERE s.barcode~'([0-9|A-z])|([A-z])|([0-9])' AND s.do_not_load=FALSE;


UPDATE staging.student_load SET card=c.id FROM actor.card c WHERE student_load.usr=c.usr AND c.barcode~'([0-9|A-z])|([A-z])|([0-9])';
UPDATE staging.student_load SET card=c.id FROM actor.card c WHERE student_load.usr=c.usr AND student_load.card IS NULL;
UPDATE actor.usr SET card=s.card FROM staging.student_load s WHERE usr.id=s.usr AND usr.card IS NULL;
UPDATE staging.student_load SET stat_cat1 = NULL WHERE usr in (SELECT s.usr FROM staging.student_load s LEFT JOIN actor.stat_cat_entry e ON s.stat_cat1=e.value WHERE s.stat_cat1 IS NOT NULL AND e.value IS NULL);
UPDATE staging.student_load SET stat_cat1 = NULL WHERE usr in (SELECT s.usr FROM staging.student_load s LEFT JOIN actor.stat_cat_entry e ON s.stat_cat2=e.value WHERE s.stat_cat2 IS NOT NULL AND e.value IS NULL);
INSERT INTO staging.student_load_log (org_unit, type, count) SELECT 152,'CREATED', count(usr) FROM staging.student_load WHERE usr IS NOT NULL AND do_not_load=FALSE;
DELETE FROM staging.student_load WHERE usr IS NOT NULL;

COMMIT;

SELECT 1 as seq, created::text, type, count::text, description FROM staging.student_load_log WHERE org_unit=152 AND created>=DATE(NOW())
UNION
SELECT 2 as seq, '----','----','----','-----'
UNION
SELECT 3 as seq, 'Students Not Loaded','----','----','-----'
UNION
SELECT 4 as seq, '----','----','----','-----'
UNION
SELECT 5 as seq, ident_value, first_given_name, family_name, email FROM staging.student_load
ORDER BY seq, created;


