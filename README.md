# CWMARS Patron Load SQL Scripts

This repository contains the SQL scripts used by CWMARS to load patron
data for our academic members.  The are based off of some SQL scripts
that were circulating in the Evergreen community some time ago.  While
we still use them, there are probably better ways to do this today.

# Usage

We install these on our utility server by cloning the repository.

Each member library has its own SQL script because we don't always do
the same things for each.

We upload a file of patrons to load to the opensrf user's home
directory and make sure it is named as appropriate for the particular
library's SQL script:

| Library | Data Filename     | SQL Filename          |
| ------- | ----------------- | --------------------- |
| AIC     | AIC_patrons.txt   | AIC_student_load.sql  |
| AMC     | AMC_patrons.txt   | AMC_student_load.sql  |
| GCC     | GCC_patrons.txt   | GCC_student_load.sql  |
| MWCC    | MWCC_patrons.txt  | MWCC_student_load.sql |

Then, we just run the sql:

```
psql -U evergreen -h dbserver -f patron_loads/AIC_student_load.sql
```
