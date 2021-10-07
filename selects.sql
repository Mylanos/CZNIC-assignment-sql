SELECT * from domain;

SELECT * from domain_flag;

/*returns fully qualified domain name of domains which are currently registered but expired*/
SELECT domain_name
FROM
    (SELECT *
        FROM domain
        WHERE now() < reg_ends_at
        AND now() >= reg_starts_at)
    AS nested
WHERE nested.flag in ('EXPIRED');


/*returns fully qualified domain name of domains which have had active outzone and expired flags*/
SELECT domain_name
FROM
    domain
WHERE id = (SELECT id_domain_fk
                FROM domain_flag
                WHERE old_flag in ('EXPIRED', 'OUTZONE')
                AND new_flag in ('EXPIRED', 'OUTZONE'));

