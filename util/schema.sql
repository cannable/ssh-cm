BEGIN TRANSACTION;
CREATE TABLE 'global' (
        'setting'       TEXT UNIQUE,
        'value'     TEXT,
        PRIMARY KEY('setting')
);
CREATE TABLE 'defaults' (
    'setting'   TEXT UNIQUE,
    'value'         TEXT,
    PRIMARY KEY('setting')
);
CREATE TABLE 'connections' (
    'id'         INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT UNIQUE,
    'nickname'      TEXT NOT NULL UNIQUE,
    'host'          TEXT NOT NULL,
    'user'          TEXT,
    'description'   TEXT,
    'args'          TEXT,
    'identity'      TEXT,
    'command'       TEXT
);
INSERT INTO 'global' (setting,value) VALUES ('schema_version','1.0');
INSERT INTO 'defaults' (setting,value) VALUES ('user',NULL);
INSERT INTO 'defaults' (setting,value) VALUES ('args',NULL);
INSERT INTO 'defaults' (setting,value) VALUES ('identity',NULL);
INSERT INTO 'defaults' (setting,value) VALUES ('command',NULL);
COMMIT;
