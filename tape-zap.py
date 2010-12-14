#!/usr/bin/env python

"""This program is for updating the status of tapes in DataProtector.

Barcode readers generally act like PS2 or USB keyboards. They enter
whatever they zap, and then send a new-line character.

So this program reads data from stdin in that format. 

It expects a command-line argument which is the location to update those
tapes to have.

Almost no error checking is done.

It needs to run on a machine which has the cell console software on it,
and as a user who has at least the rights to run omnimm.
"""

import os
import sys
import string

if len(sys.argv) == 1:
  sys.exit("Please supply a location you would like the tapes to be moved to")

dest_location = string.join(sys.argv[1:]," ")

print "Marking tapes as being in location: ",dest_location
# Perhaps I should check that this is a valid location?

if sys.platform != 'nt':
  omnimm = '/opt/omni/bin/omnimm'
else:
  for possibility in ["C:\\Program Files\\Omniback\bin\omnimm","D:\\Program Files\\Omniback\bin\omnimm"]:
    if os.path.exists(possibility):
      omnimm = possibility
      break 
  sys.exit("Can't find omnimm program")

while 1:
  print "Zap or enter the label of the tape (x to exit): ",
  tape_name = sys.stdin.readline()
  if tape_name == "": break
  # Remove newline char
  tape_name = tape_name[:-1] 
  if tape_name == 'x' or tape_name == 'X': break
  # Assume that no-one puts " or funny chars into 
  # If we were sure to be on unix, I'd just use os.fork and os.exevc so
  # that no quoting was needed
  command = '"'+omnimm+'" -modify_medium "'+tape_name+'" "'+tape_name+'" "'+dest_location+'"'
  result = os.system(command)
  if result == 0:
    print "\a",
  else:
    print "\a\a"
    sys.stderr.write("Command failed: " + command)

