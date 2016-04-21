dp-tools
========

*Programs to support HPe Data Protector*

Performance tools
-----------------

- omniperf.pl - This program prints out the throughput rate of the specified sessions,
or all current sessions if no sessions are specified.

- omniperfreport.pl - This program prints out a report on DataProtector backup throughput performance for a completed session.


Tools for migrating between cell managers and keeping them in sync
------------------------------------------------------------------

- device-replicator.pl - A script to make a two cell managers have the same pools

- dp-move-clients.pl - Generate a script to export/import every client in a cell

- mcf-all-media.pl - This program walks through everything in the media management database and writes MCF files out to the 
output directory, unless they already exist on the (optionally specified) target server. Then it copies it to
target-server-directory (with an extension of .temp, which gets changed to .mcf once it is complete).

- mega-import.pl - watches for files in the watch-directory that end in .mcf. When it sees 
one, it checks to see if it is already known about in the DataProtector internal database. 
If it is not already in the database, it is imported.

- pool-replicator.pl - A script to make a two cell managers have the same pools



Tools for copying sessions between cell managers
------------------------------------------------

These are mostly obsolete as of DP 9.04 because you would typically create a
copy job from one cell manager's storeonce to the another cell manager's storeonce.
These are still relevant if you want to keep physical tapes in two locations.

- mcfreceive.pl - process incoming MCF files

- mcfsend.pl - A script to export MCF files after a backup


Software for keeping track of tapes
-----------------------------------

- tape-zap.py - a command-line program which updates the Data Protector database of tape locations by letting you
zap the tapes with a barcode reader device

- tapescan.py - a CGI version of tape-zap.py



Miscellaneous programs that don't fit elsewhere
-----------------------------------------------

- library-pooling.pl - This program files media in a tape library into one of two media pools, based on their slot number.

- omnisms.pl - This program sends an SMS through the ValueSMS gateway to report on
mount requests. It can be used as a mount script for a device.

- try-all-devices.pl - Exercises every device (tape, storeonce, etc) by running a tiny backup to it
