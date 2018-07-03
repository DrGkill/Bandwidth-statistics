Bandwidth-statistics
====================

Table of Contents:
------------------

* [Introduction](#intro)
* [Install](#install)
* [Running the script](#running)

<a name="intro"></a>
### Introduction
This is a small PERL script that calculate network bandwidth with some stats. 

I wrote it mainly because softs like iperf have to be lauch both sides of the network you want to evaluate. This script is doing calculation from one point only with HTTP download and upload.

It's compatible with any Unix/Windows platform since you have tcpdump installed.

<a name="install"></a>
### Install

The project needs sevral Perl plugins to work properly:
* Getopt::Std
* LWP::Simple
* LWP::UserAgent
* HTTP::Request
* File::Slurp
* Time::HiRes
* IPC::Open2
* Statistics::Basic
* List::Util

Install the dependancies:
```
# apt-get install tcpdump libwww-perl libfile-slurp-perl libstatistics-basic-perl
```

<a name="running"></a>
### Running the script

Make your script executable :
```
chmod +x netbps
```

Run a download bandwidth test :
```
$ ./netbps -d -r http://cdimage.debian.org/debian-cd/7.5.0/amd64/iso-cd/debian-7.5.0-amd64-CD-1.iso -D detailed
[...]
1398512914.36;1.44
1398512914.42;2.02
1398512914.47;1.82
1398512914.52;1.65
1398512914.57;1.41
1398512914.62;1.45
1398512914.67;1.39
1398512914.72;1.35
1398512914.77;1.37
1398512914.82;1.34
1398512914.87;1.33
1398512914.92;1.32
1398512914.97;1.38
1398512915.19;1.34
1398512915.70;1.31
1398512915.12;1.32
[...]
Average : 1.4 MBps
Std Deviation : 0.22 MBps
Median : 1.34 MBps
Min : 0.00 MBps
Max : 2.24 MBps
```

Prepare a 20 MB ressource file :
```
$ dd if=/dev/urandom of=/tmp/myressource.img bs=1M count=20
```

Then have an HTTP server configured with Webdav methods enabled to accept a PUT on it.
```
$ ./netbps -r /tmp/myressource.img -s http://myserver.com/test.img -D human

Average : 0.9 MBps
Std Deviation : 0.20 MBps
Median : 0.8 MBps
Min : 0.00 MBps
Max : 1.12 MBps
```

Full help :
```
Usage:

        netbps --help |--version
        netbps -u|-d [-I interface] [-p port] [-i report_interval] [-D display_type] <-s server | -r ressource>
        netbps -d -r http://ressource
        netbps -u [-p port] [-r ressource] -s server
        netbps -u|-d [-i report interval] -s server

 -u  Upload mode (only HTTP PUT method supported for now)
 -d  Download mode (only HTTP download supported for now)
 -s  Specify a server url for upload
 -p  Specify a port on this server (default 80)
 -r  Specify a file to upload or download
        ex: netbps -u -r /blah/foo.iso -s http://server/blah/foo.iso
        ex: netbps -d -r http://server/blah/foo.iso
 -i  Specify an interval time between two checkpoint (default 50ms)
 -I  Force output/sniffing interface (default eth0)
 -D  Display type, can be "human", "script", "detailed"
 -f  Unit, can be Kbps, KBps, Mbps, MBps (default MBps)
 -t  Snaplen, the capture size of tcpdump (default 94 bytes)
 --help Display this help message
 --version Show script version
```

