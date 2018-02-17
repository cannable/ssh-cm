BEGIN TRANSACTION;
CREATE TABLE IF NOT EXISTS 'global' (
	'setting'	TEXT UNIQUE,
	'value'	    TEXT,
	PRIMARY KEY('setting')
);
CREATE TABLE IF NOT EXISTS 'defaults' (
	'default'	TEXT UNIQUE,
	'value'	    TEXT,
	PRIMARY KEY('default')
);
CREATE TABLE IF NOT EXISTS 'connections' (
	'index'	        INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT UNIQUE,
	'nickname'      TEXT NOT NULL UNIQUE,
	'host'	        TEXT NOT NULL,
	'user'	        TEXT NOT NULL,
	'description'  	TEXT,
	'arguments' 	TEXT,
	'identity'	    TEXT,
	'command'	    TEXT
);
INSERT INTO 'global' (setting,value) VALUES ('schema_version','1.0');
INSERT INTO 'defaults' (default,value) VALUES ('user',NULL);
INSERT INTO 'defaults' (default,value) VALUES ('args',NULL);
INSERT INTO 'defaults' (default,value) VALUES ('identity',NULL);
INSERT INTO 'defaults' (default,value) VALUES ('command',NULL);
COMMIT;
