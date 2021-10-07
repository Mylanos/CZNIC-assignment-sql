UPDATE domain SET flag = NULL WHERE domain_name = 'www.auda.org';
UPDATE domain SET flag = 'DELETE_CANDIDATE' WHERE domain_name = 'www.auda.org';
UPDATE domain SET flag = 'OUTZONE' WHERE domain_name = 'www.auda.org';

SELECT * from domain_flag;

SELECT * from domain;
