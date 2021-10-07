/*represents table of a domain */

DROP TABLE IF EXISTS domain_flag;
DROP TABLE IF EXISTS domain CASCADE;

CREATE EXTENSION IF NOT EXISTS btree_gist;  -- one reguired for db

/*****************************************TABLES*****************************************/

CREATE TABLE domain (
    id SERIAL PRIMARY KEY,              -- unique identifier PK
    domain_name VARCHAR(50) NOT NULL,   -- domain
    reg_starts_at timestamp ,           -- registered from timestamp
    reg_ends_at   timestamp ,           -- registered until timestamp
    flag TEXT CHECK ( flag IN ('EXPIRED', 'OUTZONE', 'DELETE_CANDIDATE')),  -- flag
    -- using gist for restricting overlapping registration dates on a same domain name
    EXCLUDE USING GIST (domain_name WITH =, tsrange(reg_starts_at, reg_ends_at) WITH &&)

); 

/*represents history of domain flags changes*/
CREATE TABLE domain_flag ( 
    id_record SERIAL PRIMARY KEY,           -- unique identifier PK
    id_domain_fk INT NOT NULL,              -- unique identifier of domain FK
    set_from TIMESTAMP NOT NULL,    -- beginning of the duration when flag was set
    set_until TIMESTAMP,             -- end of the duration when flag was set
    old_flag VARCHAR(20),                   -- old flag 
    new_flag VARCHAR(20),                   -- new flag
    FOREIGN KEY (id_domain_fk)              -- foreign key from a domain table
          REFERENCES domain (id)
); 

/*flah history table is dependable on domain table, cascade deletion*/
ALTER TABLE domain_flag ADD FOREIGN KEY (id_domain_fk)
REFERENCES domain(id) ON DELETE CASCADE;

/*****************************************TABLES*****************************************/


/***************************************FUNCTIONS***************************************/

/*on update - inserts new row to the flag history if the flag changed
            -  */
CREATE OR REPLACE FUNCTION domain_update_handler()
    RETURNS TRIGGER
    AS
$$
BEGIN
    -- for most recent record of flag change set upper date bound - not working 
    IF EXISTS (SELECT 1 FROM domain_flag WHERE new_flag = OLD.flag) THEN
        UPDATE domain_flag SET set_until = now() WHERE id_domain_fk in (OLD.id);
    END IF;

    -- detect changes of a flag on a domains with the same name
    IF  NEW.domain_name = OLD.domain_name AND NEW.flag IS DISTINCT FROM OLD.flag
        THEN
        INSERT 
        INTO domain_flag 
        ( id_domain_fk,
            old_flag, 
            new_flag, 
            set_from,
            set_until) 
        VALUES 
        ( OLD.id, 
            OLD.flag, 
            NEW.flag,
            now(),
            NULL);
    END IF;

    -- on update of domain table let changes only on a currently active registrations
    IF now() >= OLD.reg_starts_at AND now() < OLD.reg_ends_at
        THEN
        RETURN NEW;
    ELSE
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE PLPGSQL;


/*prevents from updating unmodifiable columns in flag history table*/
CREATE OR REPLACE FUNCTION prevent_domainflag_update()
  RETURNS TRIGGER AS
$$
BEGIN
    RAISE EXCEPTION 'RESTRICTED UPDATE: domain_flag history is unmodifiable apart from set_until';
END;
$$
LANGUAGE PLPGSQL VOLATILE;

/***************************************FUNCTIONS***************************************/


/***************************************TRIGGERS***************************************/

/*trigger on update of domain_flag, prevents unwanted changes*/
CREATE TRIGGER trg_prevent_update
BEFORE 
UPDATE OF   id_domain_fk, 
            old_flag, 
            new_flag, 
            set_from, 
            id_record
ON domain_flag 
FOR EACH ROW
EXECUTE PROCEDURE prevent_domainflag_update();

/*trigger on update of domain, inserts change of flag to history*/
CREATE TRIGGER update_curr_reg_domain_only
BEFORE UPDATE 
ON domain
FOR EACH ROW
EXECUTE PROCEDURE domain_update_handler(); 

/***************************************TRIGGERS***************************************/

-- some data
INSERT INTO domain (domain_name, reg_starts_at, reg_ends_at, flag) VALUES ('www.hubpages.com', '2020-1-1 6:32:23.876137', '2020-8-1 4:15:23.876137', 'EXPIRED');
INSERT INTO domain (domain_name, reg_starts_at, reg_ends_at, flag) VALUES ('www.auda.org', '2020-1-3 10:34:23.876137', '2021-10-8 9:12:23.876137', 'EXPIRED');
INSERT INTO domain (domain_name, reg_starts_at, reg_ends_at) VALUES ('www.constantcontact.com', '2021-7-1 00:15:23.876137', '2022-12-24 3:15:23.876137');
INSERT INTO domain (domain_name, reg_starts_at, reg_ends_at) VALUES ('www.vut.cz', '2019-4-3 10:15:23.876137', '2022-4-3 10:15:23.876137');
INSERT INTO domain (domain_name, reg_starts_at, reg_ends_at) VALUES ('www.milada.cz', '2023-4-3 10:15:23.876137', '2025-4-3 10:15:23.876137');


UPDATE domain SET flag = 'OUTZONE' WHERE domain_name = 'www.vut.cz';
UPDATE domain SET flag = 'EXPIRED' WHERE domain_name = 'www.vut.cz';
UPDATE domain SET flag = NULL WHERE domain_name = 'www.vut.cz';

--  uncomment for forbidden update
--  UPDATE domain_flag SET old_flag = NULL WHERE id_domain_fk = 4;


SELECT * from domain_flag;

SELECT * from domain;
