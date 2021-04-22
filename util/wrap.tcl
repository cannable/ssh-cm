#! /usr/bin/env tclsh

package require sdx

puts Cleanup...
foreach f {ssh-cm ssh-cm.bat ssh-cm.sh ssh-cm.kit} {
    set fpath [file join [pwd] $f]
    if {[file exists $fpath]} {
        file delete $fpath
    }
}

puts Wrapping...

sdx::sdx wrap ssh-cm

puts Finishing...

file rename [file join [pwd] ssh-cm] [file join [pwd] ssh-cm.kit]
foreach f {ssh-cm.bat ssh-cm.sh} {
    set fpath [file join [pwd] $f]
    if {[file exists $fpath]} {
        file delete $fpath
    }
}
