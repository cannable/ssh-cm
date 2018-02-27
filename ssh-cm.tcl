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
package require csv

set scriptDir [file dirname [info script]]
set dbPath [file join $scriptDir {data.sqlite3}]
set schemaVer 1.0
set createFlag 0


# isNickname --
#
#           Checks to see if the passed value is a valid nickname. NOTE: This
#           only performs string checks, it does not check the existence of a
#           nickname.
#
# Arguments:
#           subject     String to test
#
# Results:
#           1 if the subject is a valid nickname; 0 otherwise
#
proc isNickname {subject} {
    # Validate nickname
    if {[regexp -- {^[0-9]} $subject]} {
        # Nicknames may not begin with a digit
        return 0
    } elseif {[regexp -- {[ \t]} $subject]} {
        # Nicknames may not contain whitespace
        return 0
    }

    return 1
}


# isID --
#
#           Checks to see if the passed value is a ID. NOTE: This only performs
#           string checks, it does not check the existence of a particular ID.
#
# Arguments:
#           subject     String to test
#
# Results:
#           1 if the subject is a valid ID; 0 otherwise
#
proc isID {subject} {
    # Validate ID
    if {! [string is integer $subject]} {
        # ID must be an integer
        return 0
    } elseif {$subject <= 0} {
        # ID must be positive and non-zero
        return 0
    }

    return 1
}


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


# printDefaults --
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
    puts Connections
    db eval {SELECT * FROM connections;} conn {
        if {$conn(user) eq ""} {
            set defUser [db eval {
                SELECT value FROM defaults WHERE setting = 'user'
            }]

            if {$defUser eq "\{\}"} {
                set conn(user) {}
            } else {
                set conn(user) $defUser
            }
        }
        puts [format "%s. %s:\t%s@%s\t(%s)" \
            $conn(id) \
            $conn(nickname) \
            $conn(user) \
            $conn(host) \
            $conn(description)]
    }
}


# nicknameExists --
#
#           Check to see if the passed nickname exists
#
# Arguments:
#           nickname        Nickname to look up
#
# Results:
#           returns 1 if the passed nickname exists; 0 otherwise
#
proc nicknameExists {nickname} {
    return [db exists {SELECT id FROM connections WHERE nickname=:nickname;}]
}


# idExists --
#
#           Check to see if the passed ID exists
#
# Arguments:
#           id      ID to look up
#
# Results:
#           returns 1 if the passed ID exists; 0 otherwise
#
proc idExists {id} {
    return [db exists {SELECT id FROM connections WHERE id=:id;}]
}


# setDefault --
#
#           Sets a default parameter
#
# Arguments:
#           Arguments passed to script, minus root command name
#
# Results:
#           Stores the new default setting in the DB
#
proc setDefault {args} {
    # Perform sanity checks

    # If we got an odd number of args, bail
    if {([llength $args] % 2)} {
        puts stderr "Wrong number of arguments passed to script."
        exit 1
    }

    set validNames [list -user -args -identity -command]

    # Go through each argument and make sure it's valid
    foreach {def val} $args {
        if {$def ni $validNames} {
            puts stderr "'$def' is not a valid argument."
            exit 1
        }
    }

    # Update each default setting
    foreach {def val} $args {
        set name [string trimleft $def -]
        if {[string length $val]} {
            db eval {UPDATE 'defaults' SET value=:val WHERE setting=:name;}
        } else {
            # Value is blank, nullify value
            db eval {UPDATE 'defaults' SET value=NULL WHERE setting=:name;}
        }
    }
}


# setConnection --
#
#           Changes the properties of an existing connection
#
# Arguments:
#           conn    Connection ID or nickname
#           args    Key/value pairs of command arguments, as passed by the shell
#
# Results:
#           Deletes the passed connection row from the DB
#
proc setConnection {conn args} {
    # Perform sanity checks

    # Bail if we didn't get enough arguments
    if {([llength $args] % 2)} {
        puts stderr "Wrong number of arguments passed to script."
        exit 1
    }

    # Figure out if we got a nickname or ID
    if {[isID $conn]} {
        # Got an ID
        if {! [idExists $conn]} {
            puts stderr "Connection ID $conn does not exist."
            exit 1
        }

        set id $conn
    } elseif {[isNickname $conn]} {
        # Got a nickname
        if {! [nicknameExists $conn]} {
            puts stderr "Connection nickname '$conn' does not exist."
            exit 1
        }

        # Since we got a nickname, we need the ID
        set id [db eval {SELECT id FROM connections WHERE nickname=:conn;}]
    } else {
        # Got something incomprehensible
        puts stdout "Got an invalid ID or nickname"
        exit 1
    }

    set validNames {
        -id
        -nickname
        -host
        -user
        -description
        -args
        -identity
        -command
    }

    # Go through each argument and make sure it's valid
    foreach {setting val} $args {
        if {$setting ni $validNames} {
            puts stderr "'$setting' is not a valid argument."
            exit 1
        }

        if {$setting eq "-id"} {
            # Set command is trying to change the ID.
            # Make sure there's no collision

            if {[idExists $val]} {
                puts stderr "Can't change connection ID, as one already exists."
                exit 1
            }
        }
    }

    # Assemble SQL Statement
    set statement "UPDATE 'connections' SET "

    set flagFirstPass 1
    foreach {setting val} $args {
        # Tack on a comma if we're not the first arg
        if {! $flagFirstPass} {
            append statement ","
        } else {
            set flagFirstPass 0
        }

        append statement "[string trimleft $setting -]='$val'"
    }

    append statement " WHERE id=:id;"

    db eval $statement
}


# addConnection --
#
#           Add a new connection to the DB
#
# Arguments:
#           nickname    Connection nickname
#           args        Key/value pairs of command arguments
#
# Results:
#           Stores a new connection in the DB
#
proc addConnection {nickname args} {
    # Perform sanity checks

    # Bail if we didn't get enough arguments
    if {([llength $args] % 2)} {
        puts stderr "Wrong number of arguments passed to script."
        exit 1
    } elseif {([llength $args] < 2)} {
        puts stderr "You need to specify, at least, a host."
        exit 1
    }

    # Validate nickname
    if {[regexp -- {^[0-9]}  $nickname]} {
        puts stderr "Nickname cannot start with a number."
        exit 1
    } elseif {[regexp -- {[ \t]}  $nickname]} {
        puts stderr "Nickname ($nickname) must not contain spaces or tabs"
        exit 1
    }

    if {[nicknameExists $nickname]} {
        puts stderr "Nickname '$nickname' already in use!"
        exit 1
    }

    set validNames {
        -nickname
        -host
        -user
        -description
        -args
        -identity
        -command
    }

    # Go through each argument and make sure it's valid
    foreach {setting val} $args {
        if {$setting ni $validNames} {
            puts stderr "'$setting' is not a valid argument."
            exit 1
        }
    }

    # Make sure a host was specified
    set flagHost 0
    foreach {setting val} $args {
        if {$setting eq "-host"} {
            set flagHost 1
            break
        }
    }

    if {! $flagHost} {
        puts stderr "You must specify a host."
        exit 1
    }

    # Okay, we can FINALLY add the host
    set settings "'nickname'"
    set values "'$nickname'"
    foreach {setting val} $args {
        append settings ",'[string trimleft $setting -]'"
        append values ",'$val'"
    }

    set statement "INSERT INTO 'connections' ($settings) VALUES ($values);"

    db eval $statement
}


# rmConnection --
#
#           Removes a connection from the DB
#
# Arguments:
#           conn    Connection ID or nickname
#
# Results:
#           Deletes the passed connection row from the DB
#
proc rmConnection {conn} {
    if {[isID $conn]} {
        # Got an ID
        db eval {DELETE FROM connections WHERE id=:conn;}
    } elseif {[isNickname $conn]} {
        # Got a nickname
        db eval {DELETE FROM connections WHERE nickname=:conn;}
    } else {
        # Got something incomprehensible
        puts stdout "Got an invalid ID or nickname"
        exit 1
    }
}


# exportCSV --
#
#           Prints a list of connections in CSV format
#
# Arguments:
#           none
#
# Results:
#           Writes the list to stdout
#
proc exportCSV {} {
    set header {
        id
        nickname
        host
        user
        description
        args
        identity
        command
    }

    # Print out the header row
    puts [::csv::join $header]

    # Loop through each row in the connections table, printing the connection
    # info to stdout formatted as CSV
    db eval {SELECT * FROM connections;} conn {
        set row {}

        foreach column $header {
            lappend row $conn($column)
        }

        puts [::csv::join $row]
    }

}


# importCSV --
#
#           Reads a CSV file from stdin and imports connections
#
# Arguments:
#           none
#
# Results:
#           Imports connections into the DB, clobbering any existing
#           connections with conflicting nicknames. NOTE: If the CSV input
#           contains an id field, it'll be ignored.
#
proc importCSV {} {
    # Read the first line to ensure we have a header

    if {[gets stdin header] < 0} {
        puts stderr "You must pass CSV content to stdin."
        exit 1
    }

    #puts $header
    set columns [::csv::split $header]

    # Loop through each line, mapping values to column names
    while {[gets stdin line] >= 0} {
        set row [::csv::split $line]

        set addArgs {}
        set nickname {}

        # Assemble connection add args
        set counter -1
        foreach col $columns {
            if {$col eq "id"} {
                incr counter
            } else {
                set value [lindex $row [incr counter]]

                # We need the nickname later
                if {$col eq "nickname"} {
                    set nickname $value
                }

                # If the value is empty, don't add it
                if {!($value eq {})} {
                    lappend addArgs "-$col"
                    lappend addArgs $value
                }
            }
        }

        # Ensure we got a nickname
        if {$nickname eq {}} {
            echo stderr "ERROR: Nickname doesn't exist. Bailing."
        }

        # See if nickname exists. If it does, delete it
        if {[nicknameExists $nickname]} {
            puts "[info script] rm $nickname\; \# Remove old '$nickname'"

            # TODO: Enable this
            #rmConnection $nickname
        }

        puts "[info script] add $nickname $addArgs\; \# Add '$nickname'"

        # TODO: Enable this
        #addConnection {*}$addArgs
    }

}


# ------------------------------------------------------------------------------
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
        defaults    printDefaults
        list        printConnections
        def         {setDefault {*}[lrange $argv 1 end]}
        add         {addConnection {*}[lrange $argv 1 end]}
        set         {setConnection {*}[lrange $argv 1 end]}
        rm          {rmConnection {*}[lrange $argv 1 end]}
        export      exportCSV
        import      importCSV

        default {
            puts stderr "Eh?"
            printHelp
        }
    }
}

db close

