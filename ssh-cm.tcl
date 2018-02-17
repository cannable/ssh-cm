#! /usr/bin/env tclsh

# ssh-cm.tcl --
#
#     SSH Connection Manager
# 
# Copyright 2018 C. Annable
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# 1. Redistributions of source code must retain the above copyright notice, this
# list of conditions and the following disclaimer.
# 
# 2. Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
# 
# 3. Neither the name of the copyright holder nor the names of its contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

package require sqlite3

set scriptDir [file dirname [info script]]
set dbPath [file join $scriptDir {data.sqlite3}]
set schemaVer 1.0
set createFlag 0


# printHelp --
#
#           Prints help blurb
#
# Arguments:
#           none
#
# Results:
#           Prints the help text to stdout
#
proc printHelp {} {
    puts 2018-02-17
}


# printConnections --
#
#           Prints a list of the default settings
#
# Arguments:
#           none
#
# Results:
#           Prints the default settings to stdout
#
proc printDefaults {} {
    puts Defaults
    db eval {SELECT * FROM defaults;} defaults {
        puts [format {    %s: '%s'} $defaults(setting) $defaults(value)]
    }
}


# printConnections --
#
#           Prints a list of all connections in the DB
#
# Arguments:
#           none
#
# Results:
#           Writes the list to stdout
#
proc printConnections {} {
}



# Main

if {![file exists $dbPath]} {
    set createFlag 1
}

sqlite3 db $dbPath -create 1

if {$createFlag} {
    puts "Didn't find a connections database, so creating a new one."

    # Create the appropriate tables
    db eval {
        BEGIN TRANSACTION;
        CREATE TABLE 'global' (
        	'setting'	TEXT UNIQUE,
        	'value'	    TEXT,
        	PRIMARY KEY('setting')
        );
        CREATE TABLE 'defaults' (
            'setting'	TEXT UNIQUE,
            'value'	    TEXT,
            PRIMARY KEY('setting')
        );
        CREATE TABLE 'connections' (
            'index'         INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT UNIQUE,
            'nickname'      TEXT NOT NULL UNIQUE,
            'host'          TEXT NOT NULL,
            'user'          TEXT NOT NULL,
            'description'   TEXT,
            'arguments'     TEXT,
            'identity'      TEXT,
            'command'       TEXT
        );
        INSERT INTO 'global' (setting,value) VALUES ('schema_version','1.0');
        COMMIT;
    }

    db eval {
        BEGIN TRANSACTION;
        INSERT INTO 'defaults' (setting,value) VALUES ('user',NULL);
        INSERT INTO 'defaults' (setting,value) VALUES ('args',NULL);
        INSERT INTO 'defaults' (setting,value) VALUES ('identity',NULL);
        INSERT INTO 'defaults' (setting,value) VALUES ('command',NULL);
        COMMIT;
    }

} else {
    # See if we need to update the schema
    # Right now, since there is only one version, perform a sanity check

    # Attempt to read the schema version
    set v [db eval {SELECT value FROM global WHERE setting = 'schema_version'}]

    if {($v eq "") || (![string is double $v])} {
        error "Database file is seriously borked."
        exit 1
    }

    if {$v != $schemaVer} {
        puts "Schema upgrade required."
    }
}

# Command interpreter

if {$argc == 0} {
    # Run the default command
    printHelp
} else {
    switch -- [lindex $argv 0] {
        default {
            puts stderr "Eh?"
            printHelp
        }
    }
}

db close

