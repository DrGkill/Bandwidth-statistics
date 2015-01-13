#!/usr/bin/perl
###############################################################################
# Script Name:	netbps
# Author: 	Guillaume Seigneuret
# Date: 	06.01.2014
# Last mod	09.05.2014
# Version:	1.0
# 
# Usage:	netbps
# 
# Usage domain: To be executed by  
# 
# Args :		
#
# Config: 	
# 
# Config file:	
#
#   Copyright (C) 2014 Guillaume Seigneuret (Omega Cube)
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/
###############################################################################


use strict;
use Getopt::Std;
use LWP::Simple;
use LWP::UserAgent;
use HTTP::Request;
use File::Slurp;
use POSIX ":sys_wait_h";
use Time::HiRes qw(usleep);
use IPC::Open2;
use Statistics::Basic qw(:all);
use List::Util qw(first max min reduce sum);

my %opts;
getopts('udPI:p:i:r:s:D:f:',\%opts);  

my $VERSION 		= "0.9";
$| = 1;
my $reporting_interval 	= 0.05; # seconds
my $bytes_this_interval = 0;
my $ressource 		= "/tmp/ressource.img";
my $port 		= 80;
my $interface		= "eth0";
my $display_type	= "human";
my $unit		= "MBps";
my $url			= "";
my $FLAG		= 0;

HELP_MESSAGE() && exit 1 unless (defined $opts{s} or defined $opts{r} or defined $opts{P});

$reporting_interval 	= $opts{i} if defined $opts{i};
$ressource		= $opts{r} if defined $opts{r};
$port			= $opts{p} if defined $opts{p};
$interface		= $opts{I} if defined $opts{I};
$display_type	= $opts{D} if defined $opts{D};
$unit			= $opts{f} if defined $opts{f};
$url			= $opts{s};

#print Dumper(\%opts);

my $start_time = [Time::HiRes::gettimeofday()];

my $tcpdump_pid = open2(\*CHLD_OUT, \*CHLD_IN, 'tcpdump', '-i', $interface, '-l', '-e', '-n', 'port', $port);

#select(undef, undef, undef, 0.1);

unless(fork()){
	getstore($ressource, "/dev/null") if defined $opts{d};
	upload($url, $port, $ressource) if defined $opts{u};
	
	if (defined $opts{P}){
		my @wheel=("|", "/", "-", "\\"); 
		$SIG{'INT'} = sub {$FLAG = 1};
		my $iterator = 0;
		while(1) {
			last if $FLAG == 1;
			#print $wheel[($iterator%4)];
			#$iterator == 100000 ? $iterator=1 : $iterator++;
			usleep(100000);
			#print "\b";
		}
	}
	kill 'HUP', $tcpdump_pid;
}
else {
	waitpid(-1, WNOHANG);
	$SIG{'INT'} = "IGNORE";
	my @data_plot = ();
	my $unit_value = 1048576; # MBps
	$unit_value = 131072 if $unit eq "Mbps";
	$unit_value = 1024 if $unit eq "KBps";
	$unit_value = 128 if $unit eq "Kbps";
	while (<CHLD_OUT>) {
		if (/ length (\d+):/) {
			$bytes_this_interval += $1;
			my $elapsed_seconds = Time::HiRes::tv_interval($start_time);
			if ($elapsed_seconds > $reporting_interval) {
				# Bytes: 1048576; Bits: 131072
				my $Mbps = $bytes_this_interval / $elapsed_seconds / $unit_value;
				$start_time = [Time::HiRes::gettimeofday()];
				printf "%.2f;%.2f\n", $start_time->[0].'.'.$start_time->[1],$Mbps if $display_type eq "detailed";
				printf "%.2f: %.2f %s\n", $start_time->[0].'.'.$start_time->[1],$Mbps, $unit if $display_type eq "human";
				push @data_plot, sprintf("%.2f", $Mbps);
				$bytes_this_interval = 0;
	  		}
		}
	}
	show_stats(\@data_plot,$display_type,$unit);
}

sub show_stats {
	my ($data_plot, $display_type) = @_;
	if ( $display_type eq "human" ) {
		print "Stats:\n";
		print "Average : ".mean(@$data_plot)." $unit\n";
		print "Std Deviation : ".stddev(@$data_plot)." $unit\n";
		print "Median : ".median(@$data_plot)." $unit\n";
		print "Min : ".min(@$data_plot)." $unit\n";
		print "Max : ".max(@$data_plot)." $unit\n";
	}

	if ($display_type eq "script" or $display_type eq "detailed") {
		print mean(@$data_plot).";".stddev(@$data_plot).";".median(@$data_plot).";".min(@$data_plot).";".max(@$data_plot)."\n";
	}
}

sub upload {
	my ($url, $port, $ressource) = @_;

	return 0 unless -f $ressource;


	my $content 	= read_file($ressource, { binmode => ':raw' });
	my $ua 		= LWP::UserAgent->new;
	my $req 	= HTTP::Request->new("PUT", $url);
       	$req->content($content);	

	my $res = $ua->request($req);

	return 1;
}

sub HELP_MESSAGE {
	print "Usage:\n
	netbps --help |--version
	netbps -u|-d|-P [-I interface] [-p port] [-i report_interval] [-D display_type] <-s server | -r ressource>
        netbps -u|-d -s server
        netbps -u|-d [-p port] [-r ressource] -s server
        netbps -u|-d [-i report interval] -s server\n
 -u  Upload mode (only HTTP PUT method supported for now)
 -d  Download mode (only HTTP download supported for now)
 -P  Passive mode (Make the traffic goes through the port you want and stalk it)
 -s  Specify a server url for upload
 -p  Specify a port on this server (default 80)
 -r  Specify a file to upload or download 
 	ex: netbps -u -r /blah/foo.iso -s http://server/blah/foo.iso
	ex: netbps -d -r http://server/blah/foo.iso
 -i  Specify an interval time between two checkpoint (default 50ms)
 -I  Force output/sniffing interface (default eth0)
 -D  Display type, can be \"human\", \"script\", \"detailed\"
 -f  Unit, can be Mbps or MBps (default MBps)
 --help Display this help message
 --version Show script version\n";
	exit 1;
}

sub VERSION_MESSAGE {
	print "netbps v$VERSION by Guillaume Seigneuret (C) 2014 Omega Cube\n\n";
}

sub STANDARD_HELP_VERSION {
	print "";
}
