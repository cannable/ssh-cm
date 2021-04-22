# SSH Connection Manager
A simple SSH connection manager written completely in Tcl.

# Prerequisites

* Tcl. This was developed and tested on 8.6.8, but should work on older builds. Tclkits work pretty well.
* sqlite3 (probably built-in)
* platform (also probably built-in)
* csv (from tcllib)

## Windows

To make this work on Windows, you will need a recent-ish build of Win10 or Server 2019 and the OpenSSH Client feature installed.

# Usage

Here are the commands you can use:
```
ssh-cm.tcl add 'nickname' -host 127.0.0.1 -user me
ssh-cm.tcl connect id
ssh-cm.tcl connect nickname
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
ssh-cm.tcl set 'nickname' -nickname 'another_nick'
ssh-cm.tcl set id -command tmux
```

## Add Connection

`ssh-cm.tcl add home -host 127.0.0.1 -user me`

Add a connection to the DB.

The following options are required when adding a connection:

* 'nickname' - Nickname for the connection.
  * The first character must be a letter or symbol.
  * Numbers are allowed, just as the first character.
  * No spaces.
* -host - Host name or IP address of target system.
  * NOTE: This script does no validation of host names. In other words,
    whatever is set here will be passed to SSH verbatim.

The following options are optional:

(NOTE: Null values will inherit the default value.)

* -user - Target user name
  * Like host names, no validation is done on this
  * If you don't specify a user, the connection default value will be used.
  * If you don't specify a connection default user either, the name of the
    current user running this script will be used.
* -args - Any additional arguments you want to pass to SSH.
* -description
* -identity - Path to an identity file. Again, no validation.
* -id - You can request a particular ID number. This is the row ID in the
  database. In the event of a conflict, this script will let sqlite decide what
  ID it gets.

## Connect

Start a connection. You can start by nickname or ID:

```
ssh-cm.tcl connect 'nickname'
ssh-cm.tcl connect id
```

## Set Default Connection Options

`ssh-cm.tcl def -user root -identity ~/.ssh/id_rsa`

## Print Default Connection Options

`ssh-cm.tcl defaults`
    
# Export

`ssh-cm.tcl export`

Exports all connections as CSV to stdout. You'll get output like the following:

```
id,nickname,host,user,description,args,identity,command
1,tank,bsdbox,notroot,,,,
2,asdf,linux,,,,,
```

## Import

`ssh-cm.tcl import`

Imports connections from stdin. Supported columns:

```
id,nickname,host,user,description,args,identity,command
```

The nickname and host columns are mandatory. All other columns are optional,
including the id field. If you don't include an id, the id will be generated
on-the-fly and autoincrement. Connections will be imported in same order that
they are in the input stream.

Also note that the columns need not be in the exact order as listed above. This
was done so as to make importing from other tools a little less annoying.

The import process can be picky at times. It should mostly work, but may bail
on some lines. If this happens, look for extra quotation marks, apostrophes, or
commas in the line.  Apostrophes in the description field tend to be a common
issue, and escaping characters gets somewhat silly.

## List Connections

`ssh-cm.tcl list`

List all connections in the DB. If you have a LOT of connections, this could
get unpleasant. Fast. Instead, consider searching.

## Remove Connection

You can remove by nickname or ID:
```
ssh-cm.tcl rm 'nickname'
ssh-cm.tcl rm id
```

## Search

Search the DB for connections matching your query.
There are two search syntaxes available:

1. Generic search - pass a single argument
2. Specific search - pass multiple arguments

### Generic Search

This is the simplest search to perform. This type of search will retrieve
connections containing your search string in the user, host, nickname, and
description fields. Example:

`sh-cm.tcl search 'something'`

### Specific Search

You can search specific columns using this method. The syntax is the same as
the add and set functions.  Example:

`sh-cm.tcl search -host 127.0.0.1`

## Alter Existing Connection
```
ssh-cm.tcl set 'nickname' -nickname 'another_nick'
ssh-cm.tcl set id -command tmux
```
You must identify the connection you want to alter.
To do so, you have two options:

1. 'nickname' - Nickname for the connection.
2. id - Connection ID number. This is the DB row.
            
The following options can be set (or unset):

(NOTE: Null values will inherit the default value.)

* -host - Host name or IP address of target system.
  * NOTE: This script does no validation of host names.
    In other words, whatever is set here will be
    passed to SSH verbatim.
* -user - Target user name
  * Like host names, no validation is done on this
  * If you don't specify a user, the connection
    default value will be used.
  * If you don't specify a connection default user
    either, the name of the current user running this
    script will be used.
* -nickname - Nickname for the connection.
  * The first character must be a letter or symbol.
  * Numbers are allowed, just as the first character.
  * No spaces.
* -args - Any additional arguments you want to pass to SSH.
* -description
* -identity - Path to an identity file. Again, no validation.
* -id - You can request a particular ID number. This is the
    row ID in the database. In the event of a conflict,
    the ID will not be changed.
            
To unset any of these options, set the value to null string.
Ex. You want to remove the custom user name from connection 7
    and just use the connection default name (as set by def).

`ssh-cm.tcl set 7 -user ''`

Any null string will set the DB column to a proper NULL.
