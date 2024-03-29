#! /usr/bin/env tclsh

# ssh-cm.tcl --
#
#     SSH Connection Manager
# 
# Copyright 2021 C. Annable
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
package require platform

package provide app-ssh-cm 1.0


# ------------------------------------------------------------------------------
# Default Settings

# Don't change these unless you know what you're doing.
set schemaVer 1.1

# These are fallback settings and setting anything here probably won't do
# anything. Connection and app defaults are stored in the DB and that's the
# better place to tweak things.
array set connectionDefaults {
        binary      ssh
        args        {}
        command     {}
        description {}
        host        {}
        id          {}
        identity    {}
        nickname    {}
        setting     {}
        user        {}
}

# getDBPath --
#
#           Attempts to locate the path to the DB file
#
# Arguments:
#           None
#
# Results:
#           Returns path to the DB file
#
proc getDBPath {} {
    set dbName {ssh-cm.connections}

    set toCheck [list [file join ~ .config $dbName]]
    lappend toCheck [file join [file dirname [info script]] $dbName]

    # Try to locate an existing DB
    foreach path $toCheck {
        if {[file exist $path]} {
            return $path
        }
    }

    # Since we couldn't locate a DB, return the preferred path for creation
    return [list [file join ~ .config $dbName]]
}


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
#           args    Optional: a subcommand for which to show detailed help info.
#
# Results:
#           Prints the help text to stdout
#
proc printHelp {args} {

    switch -- [lindex $args 0] {
        help {
            puts "Print help. Pass a subcommand for more topical help."
            return
        }

        defaults {
            puts "Print the default settings for connections."
            return
        }

        list {
            puts "List all connections in the DB."
            puts -nonewline "NOTE: If you have a LOT of connections, "
            puts "this could get unpleasant. Fast."
            return
        }

        add {
            puts "Add a connection. An example:\n"
            puts "\t\tssh-cm.tcl add home -host 127.0.0.1 -user me\n"
            puts "The following options are required when adding a connection:"
            puts {
                'nickname'  Nickname for the connection.
                            * The first character must be a letter or symbol.
                            * Numbers are allowed, just as the first character.
                            * No spaces.

                -host       Host name or IP address of target system.
                            NOTE: This script does no validation of host names.
                                  In other words, whatever is set here will be
                                  passed to SSH verbatim.
            }

            puts "The following options are optional:"
            puts "\n(NOTE: Null values will inherit the default value.)"
            puts {
                -user       Target user name
                            * Like host names, no validation is done on this
                            * If you don't specify a user, the connection
                              default value will be used.
                            * If you don't specify a connection default user
                              either, the name of the current user running this
                              script will be used.

                -args       Any additional arguments you want to pass to SSH.

                -description

                -identity   Path to an identity file. Again, no validation.

                -id         You can request a particular ID number. This is the
                            row ID in the database. In the event of a conflict,
                            this script will let sqlite decide what ID it gets.
            }

            return
        }

        def {
            puts "Set default connection settings. Ex.\n"
            puts "\tssh-cm.tcl def -user root -identity ~/.ssh/id_rsa\n"
            return
        }

        set {
            puts "Alter an existing connection. Some examples:\n"
            puts "\t\tssh-cm.tcl set 'nickname' -nickname 'another_nick'"
            puts "\t\tssh-cm.tcl set id -command tmux\n"
            puts "You must identify the connection you want to alter."
            puts "To do so, you have two options:"

            puts {
                'nickname'  Nickname for the connection.

                -or-

                id          Connection ID number. This is the DB row.
            }

            puts "The following options can be set (or unset):"
            puts "\n(NOTE: Null values will inherit the default value.)"
            puts {
                -host       Host name or IP address of target system.
                            NOTE: This script does no validation of host names.
                                  In other words, whatever is set here will be
                                  passed to SSH verbatim.

                -user       Target user name
                            * Like host names, no validation is done on this
                            * If you don't specify a user, the connection
                              default value will be used.
                            * If you don't specify a connection default user
                              either, the name of the current user running this
                              script will be used.

                -nickname   Nickname for the connection.
                            * The first character must be a letter or symbol.
                            * Numbers are allowed, just as the first character.
                            * No spaces.

                -args       Any additional arguments you want to pass to SSH.

                -description

                -identity   Path to an identity file. Again, no validation.

                -id         You can request a particular ID number. This is the
                            row ID in the database. In the event of a conflict,
                            the ID will not be changed.
            }
            puts "To unset any of these options, set the value to null string."
            puts "Ex. You want to remove the custom user name from connection 7"
            puts "    and just use the connection default name (as set by def)."

            puts "\n\t\tssh-cm.tcl set 7 -user ''"

            puts "Any null string will set the DB column to a proper NULL."

            return
        }

        rm {
            puts "Remove a connection. You can remove by nickname or ID:"
            puts "\t\tssh-cm.tcl rm 'nickname'"
            puts "\t\tssh-cm.tcl rm id"
            return
        }

        connect {
            puts "Start a connection. You can start by nickname or ID:"
            puts "\t\tssh-cm.tcl connect 'nickname'"
            puts "\t\tssh-cm.tcl connect id"
            puts "\nYou can also connect using the short form (c):"
            puts "\t\tssh-cm.tcl c 'nickname'"
            puts "\t\tssh-cm.tcl c id"
            return
        }

        export {
            puts "Exports all connections as CSV to stdout, in this format:\n"
            puts "id,nickname,host,user,description,args,identity,command"
            puts "1,tank,bsdbox,notroot,,,,"
            puts "2,asdf,linux,,,,,\n"
            return
        }

        import {
            puts "Imports connections from stdin. Supported columns:\n"
            puts "id,nickname,host,user,description,args,identity,command"

            puts "\nThe nickname and host columns are mandatory. All other"
            puts "columns are optional, including the id field. If you don't"
            puts "include an id, the id will be generated on-the-fly and"
            puts "autoincrement. Connections will be imported in same order"
            puts "that they are in the input stream.\n"

            puts "Also note that the columns need not be in the exact order as"
            puts "listed above. This was done so as to make importing from"
            puts "other tools a little less annoying.\n"

            puts "The import process can be picky at times. It should mostly"
            puts "work, but may bail on some lines. If this happens, look for"
            puts "extra quotation marks, apostrophes, or commas in the line."
            puts "Apostrophes in the description field tend to be a common"
            puts "issue, and escaping characters gets somewhat silly."

            return
        }

        search {
            puts "Search the DB for connections matching your query."
            puts "Also, you can shorten the 'search' command to just 's'."
            puts "There are two search syntaxes available:"
            puts "  1. Generic search - pass a single argument"
            puts "     This is the simplest search to perform. This type of"
            puts "     search will retrieve connections containing your search"
            puts "     string in the user, host, nickname, and description"
            puts "      fields. Example:\n"
            puts "          sh-cm.tcl search 'something'"
            puts "          sh-cm.tcl s 'something'\n"
            puts "  2. Specific search - pass multiple arguments"
            puts "     You can search specific columns using this method. The"
            puts "     syntax is the same as the add and set functions."
            puts "     Example:\n"
            puts "          sh-cm.tcl search -host 127.0.0.1"
            puts "          sh-cm.tcl s -host 127.0.0.1\n"
            return
        }

    }
 
    # Assume that the user either passed an invalid subcommand name or nothing
    puts "SSH Connection Manager"
    puts "Written completely in Tcl by CANNABLE."

    puts "\nHere are the commands you can use:"
    puts {
        ssh-cm.tcl add 'nickname' -host 127.0.0.1 -user me
        ssh-cm.tcl connect id
        ssh-cm.tcl connect nickname
        ssh-cm.tcl c id
        ssh-cm.tcl c nickname
        ssh-cm.tcl def -user root -identity ~/.ssh/id_rsa
        ssh-cm.tcl defaults
        ssh-cm.tcl export
        ssh-cm.tcl help
        ssh-cm.tcl import
        ssh-cm.tcl list
        ssh-cm.tcl rm 'nickname'
        ssh-cm.tcl rm id
        ssh-cm.tcl search 'something'
        ssh-cm.tcl search -host 127.0.0.1
        ssh-cm.tcl s 'my sanity'
        ssh-cm.tcl s -host 127.0.0.2
        ssh-cm.tcl set 'nickname' -nickname 'another_nick'
        ssh-cm.tcl set id -command tmux
    }
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
    puts "Configured Defaults (DB)"
    db eval {SELECT * FROM defaults ORDER BY setting;} defaults {
        puts [format {    %s: '%s'} $defaults(setting) $defaults(value)]
    }

    puts "\nApp Defaults (Hard-Coded)"

    foreach key [lsort [array names ::connectionDefaults]] {

        # Don't print connection settings which'd be obtained from the DB
        if {[lsearch {description id host setting nickname id} $key] < 0} {
            puts [format "    %s: '%s'" $key $::connectionDefaults($key)]
        }
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
    db eval {SELECT id FROM connections;} conn {
        array set c [getConnection $conn(id)]
        #parray c
        puts [format "%s. %s:\t%s@%s\t(%s)" \
            $c(id) \
            $c(nickname) \
            $c(user) \
            $c(host) \
            $c(description)]
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
    set flagSetID 1
    foreach {setting val} $args {
        if {$setting ni $validNames} {
            puts stderr "'$setting' is not a valid argument."
            exit 1
        }

        if {[idExists $val]} {
            # Adding connections with a particular ID is best effort.  If
            # there's a collision, we'll still add the connection, just not at
            # the requested ID.
            puts stderr "WARN: Requested ID not available."
            set flagSetID 0
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
        if {$setting eq "-id"} {
            if {$flagSetID} {
                append settings ",'[string trimleft $setting -]'"
                append values ",'$val'"
            }
        } else {
            append settings ",'[string trimleft $setting -]'"
            append values ",'$val'"
        }
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
                set id [lindex $row [incr counter]]

                if {![idExists $id]} {
                    lappend addArgs "-id" $id
                }
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
            puts stderr "ERROR: Nickname doesn't exist. Bailing."
        }

        # See if nickname exists. If it does, we'll do a set vs. add
        if {[nicknameExists $nickname]} {
            puts "[info script] set $nickname $addArgs\; \# Alter '$nickname'"

            setConnection $nickname {*}$addArgs
        } else {
            puts "[info script] add $nickname $addArgs\; \# Add '$nickname'"

            addConnection $nickname {*}$addArgs
        }
    }

}


# getConnection --
#
#           Merges OS, application default, and connection settings
#
# Arguments:
#           id      Connection ID
#
# Results:
#           Returns a list of connection info
#
proc getConnection {id} {
    # Pass 0: Hard-Coded, Ugly, Defaults
    array set c [array get ::connectionDefaults]

    # Pass 1: System Default Values
    # The default user is the one running this script
    if {"USER" in [array names ::env]} {
        array set c [list user $::env(USER)]
    }

    # Pass 2: Application Default Values
    db eval {SELECT setting,value FROM defaults;} defs {
        # Skip null values
        if {[string length $defs(value)]} {
            set c($defs(setting)) $defs(value)
        }
    }


    # Now we need the connection info from the DB
    db eval {SELECT * FROM connections WHERE id=:id;} cfg {
        # Merge the data (we are stripping out null values here)
        foreach setting [array names cfg] {
            if {[string length $cfg($setting)]} {
                set c($setting) $cfg($setting)
            }
        }
    }

    # Pass 3: Connection Values

    return [array get c]
}


# connect --
#
#           Assembles a command line string for the requested connection, then
#           executes
#
# Arguments:
#           conn    Either an ID or a nickname
#
# Results:
#           Starts SSH client with appropriate arguments
#
proc connect {conn} {
    # Now we need the connection info from the DB
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

        set id [db eval {SELECT id FROM connections WHERE nickname=:conn;}]
    } else {
        # Got something incomprehensible
        puts stdout "Got an invalid ID or nickname"
        exit 1
    }

    array set c [getConnection $id]

    # From here on down, c is an array that contains our connection info

    # OpenSSH
    set command "$c(binary)"

    if {[string length $c(args)]} {
        append command " $c(args)"
    }

    if {[string length $c(identity)]} {
        append command " -i $c(identity)"
    }

    append command [format { %s@%s} $c(user) $c(host)]

    catch {exec -- {*}$command <@stdin >@stdout 2>@stderr}
}


# search --
#
#           Searches for connections based on user input.
#
# Arguments:
#           args    Search arguments. Can be two types of search:
#                       * Single argument: searches varous fields for pattern
#                       * Multiple args: specific parameters were passed
#
# Results:
#           Starts SSH client with appropriate arguments
#
proc search {args} {
    set query ""

    if {! [llength $args]} {
        printHelp
        exit
    } elseif {[llength $args] == 1} {
        # Single search argument passed, perform general search
        set query "SELECT id FROM connections WHERE (nickname LIKE '%$args%')"
        append query " OR (host LIKE '%$args%')"
        append query " OR (user LIKE '%$args%')"
        append query " OR (description LIKE '%$args%')"
        append query " ORDER BY id;"
    } elseif {([llength $args] % 2)} {
        puts stderr "Wrong number of arguments passed to script."
        exit 1
    } else {
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

        set query "SELECT id FROM connections WHERE"
        # Go through each argument and, if it's valid, add it to the query
        set flagFirstRun 1
        foreach {setting val} $args {
            if {$setting ni $validNames} {
                puts stderr "'$setting' is not a valid argument."
                exit 1
            }

            if {$flagFirstRun} {
                set flagFirstRun 0
                append query " ([string trimleft $setting -] LIKE '%$val%')"
            } else {
                append query " AND ([string trimleft $setting -] LIKE '%$val%')"
            }

        }

        append query " ORDER BY id;"
    }

    # Perform search
    db eval $query conn {
        array set c [getConnection $conn(id)]
        #parray c
        puts [format "%s. %s:\t%s@%s\t(%s)" \
            $c(id) \
            $c(nickname) \
            $c(user) \
            $c(host) \
            $c(description)]
   }
}


# ------------------------------------------------------------------------------
# Main/Database Handling

set dbPath [getDBPath]

if {![file exists $dbPath]} {
    puts "Didn't find a connections database, so creating a new one."

    set dbDir [file dirname $dbPath]

    # Do some sanity checks on the dbDir
    if {![file exists $dbPath]} {
        puts "Creating $dbDir."
        file mkdir $dbDir
    }

    # Create file
    if {[catch {sqlite3 db $dbPath -create 1}]} {
        error "Can't create DB file"
    }

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
            'command'       TEXT,
            'binary'        TEXT
        );
        INSERT INTO 'global' (setting,value) VALUES ('schema_version','1.1');
        COMMIT;
    }

    db eval {
        BEGIN TRANSACTION;
        INSERT INTO 'defaults' (setting,value) VALUES ('binary',NULL);
        INSERT INTO 'defaults' (setting,value) VALUES ('user',NULL);
        INSERT INTO 'defaults' (setting,value) VALUES ('args',NULL);
        INSERT INTO 'defaults' (setting,value) VALUES ('identity',NULL);
        INSERT INTO 'defaults' (setting,value) VALUES ('command',NULL);
        COMMIT;
    }

} else {
    # Open connections DB
    sqlite3 db $dbPath -create 1

    # Attempt to read the schema version
    set v [db eval {SELECT value FROM global WHERE setting = 'schema_version'}]

    if {($v eq "") || (![string is double $v])} {
        error "Database file is seriously borked."
        exit 1
    }

    if {$v > $schemaVer} {
        puts "This tool is too old to use this new DB file."
        puts "Please update."
        puts "\nSchema:"
        puts "\tTool: $schemaVer"
        puts "\tFile: $v"
        exit 1
    }

    if {$v < $schemaVer} {
        puts "Schema upgrade required."
        puts "\nSchema:"
        puts "\tTool: $schemaVer"
        puts "\tFile: $v\n"

        # Each if statement will perform an upgrade between versions
        if {$v == 1.0} {
            puts "Upgrading v1.0 schema to v1.1..."

            db eval {
                BEGIN TRANSACTION;
                ALTER TABLE 'connections' ADD COLUMN 'binary' TEXT;
                INSERT INTO 'defaults' (setting,value) VALUES ('binary',NULL);
                UPDATE 'global' SET value='1.1' WHERE setting='schema_version';
                COMMIT;
            }

            set v "1.1"

            puts "Complete.\n"
        }

        # Future: next if statement will upgrade to 1.2
    }
}


# ------------------------------------------------------------------------------
# Main/Command Validation

# Technically, this block should be before we open the database file. It's here
# with the command processor switch statement for simplicity's sake


# validCommands: Contains a list of all valid commands
set validCommands {
    add
    connect
    def
    defaults
    export
    help
    import
    list
    rm
    search
    set
}

# cmdAliases: An array where keys are subcommand aliases and values are the root
#             subcommands
array set cmdAliases {
    c connect
    s search
}

# noArgCmds: A list containing subcommands that take no arguments
set noArgCmds {defaults list export import}


# If no arguments are passed to the script, print general help and exit
# gracefully
if {[llength $argv] == 0} {
    printHelp
    exit 0
}

set subcommand [lindex $argv 0]

# If the subcommand is an alias, switch to the actual subcommand name
if {[lsearch [array names cmdAliases] $subcommand] >= 0} {
    set subcommand $cmdAliases($subcommand)
}

# If the subcommand isn't supported, print general help and exit angry
if {[lsearch $validCommands $subcommand] < 0} {
    puts stderr "Unknown instruction '$subcommand'\n."
    printHelp
    exit 1
}

# If the subcommand requires arguments and none are passed, print specific help
# and exit angry
if {[llength $argv] < 2 && [lsearch $noArgCmds $subcommand] < 0} {
    puts stderr "Missing arguments to '$subcommand'.\n"
    printHelp $subcommand
    exit 1
}


# ------------------------------------------------------------------------------
# Main/Command Processing

# Command interpreter
switch -- $subcommand {
    connect     {connect {*}[lindex $argv 1]}
    defaults    printDefaults
    list        printConnections
    def         {setDefault {*}[lrange $argv 1 end]}
    add         {addConnection {*}[lrange $argv 1 end]}
    set         {setConnection {*}[lrange $argv 1 end]}
    rm          {rmConnection {*}[lrange $argv 1 end]}
    export      exportCSV
    import      importCSV
    search      {search {*}[lrange $argv 1 end]}
    help        {printHelp {*}[lindex $argv 1]}
}

db close
