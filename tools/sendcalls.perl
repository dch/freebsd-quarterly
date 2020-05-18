#!/usr/bin/env perl
#
# Copyright (c) 2020 Lorenzo Salvadore
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

use strict;
use warnings;

use Getopt::Std;

my $day;
my $month;
my $year;
my $quarter;
my $urgency_tag;
my @destinataries = ();
my %template_substitutions;
my %options;

$template_substitutions{1}{'%%START%%'}	=	'January';
$template_substitutions{1}{'%%STOP%%'}	=	'March';
$template_substitutions{1}{'%%DEADLINE%%'}	=	'April, 1st';
$template_substitutions{2}{'%%START%%'}	=	'April';
$template_substitutions{2}{'%%STOP%%'}	=	'June';
$template_substitutions{2}{'%%DEADLINE%%'}	=	'July, 1st';
$template_substitutions{3}{'%%START%%'}	=	'July';
$template_substitutions{3}{'%%STOP%%'}	=	'September';
$template_substitutions{3}{'%%DEADLINE%%'}	=	'October, 1st';
$template_substitutions{4}{'%%START%%'}	=	'October';
$template_substitutions{4}{'%%STOP%%'}	=	'December';
$template_substitutions{4}{'%%DEADLINE%%'}	=	'January, 1st';

$main::VERSION = "[not versioned]";
$Getopt::Std::STANDARD_HELP_VERSION = 1;

sub main::HELP_MESSAGE
{
	print <<EOT;
Usage: ./sendcalls.perl [-d day] [-m month] [-y year] [-t] -s signature

Options:
	-d day		Day of the month: [1-31].
	-m month	Month: [1-12].
	-y year		Year: >= 1970
			(I think you are unlikely to send calls before
			the Unix epoch. And I am writing it in 2020.)
	-t		Testing flag. Set it it you want to test the
			script without actually send mails.
	-s signature	Name to use for signing the quarterly calls mail.

Example:
	./sendcalls.perl -d 31 -m 2 -y 2000 -s 'Lorenzo Salvadore'
	(Yes, you can send calls even on inexistent days such as
	2020 February, 31st.)
EOT
	exit 1;
}

getopts('d:m:y:s:t', \%options);

main::HELP_MESSAGE if(not $options{'s'});

(undef, undef, undef, $day, $month, $year, undef, undef, undef) = localtime();
$year = $year + 1900;

$day = $options{'d'} if($options{'d'});
$month = $options{'m'} - 1 if($options{'m'});
$year = $options{'y'} if($options{'y'});

die "Choosen date does not seem plausibile: year is $year, month is $month and day is $day"
if(	$day < 1 or
	$day > 31 or
	$month < 1 or
	$month > 12 or
	$year < 1970	);

if($day < 14)
{
	$urgency_tag = '';
}
elsif($day < 23)
{
	$urgency_tag = '[2 WEEKS LEFT REMINDER] ';
}
else
{
	$urgency_tag = '[LAST OFFICIAL REMINDER] ';
}

$quarter = int($month / 3) + 1;

$template_substitutions{$quarter}{'%%SIGNATURE%%'} = $options{'s'};

my $year_last = $year;
my $quarter_last = $quarter - 1;
if($quarter == 0)
{
	$year_last = $year_last - 1;
	$quarter = 4;
}
my $quarter_last_directory = '../'.$year_last.'q'.$quarter_last;
foreach(`ls $quarter_last_directory`)
{
	$_ =~ tr/\n//d;
	open(quarterly_report, '<', $quarter_last_directory.'/'.$_) or
	die "Could not open $quarter_last_directory/$_: $!";
	while(<quarterly_report>)
	{
		if($_ =~ m/^Contact:.*(<.*@.*>)/)
		{
			my $address = $1;
			$address =~ tr/<>//d;
			push @destinataries, $address;
		}
	}
	close(quarterly_report);
}

my %tmp = map {$_ => 0} @destinataries;
@destinataries = keys %tmp;

$template_substitutions{$quarter}{'%%QUARTER%%'} = $quarter;
$template_substitutions{$quarter}{'%%YEAR%%'} = $year;
if($quarter != 4)
{
	$template_substitutions{$quarter}{'%%DEADLINE%%'} =
	$template_substitutions{$quarter}{'%%DEADLINE%%'}.' '.$year;
}
else
{
	$template_substitutions{$quarter}{'%%DEADLINE%%'} =
	$template_substitutions{$quarter}{'%%DEADLINE%%'}.' '.($year + 1);
}
open(call_template, '<', 'call.txt.template') or
die "Could not open call.txt.template: $!";
open(call_mail, '>', 'call.txt') or
die "Could not open call.txt: $!";
while(<call_template>)
{
	my $line = $_;
	$line =~ s/$_/$template_substitutions{$quarter}{$_}/g
		foreach(keys %{ $template_substitutions{$quarter} });
	print call_mail $line;
}
close(call_template);
close(call_mail);

my $summary = $urgency_tag."Call for ".$year."Q".$quarter." quarterly status reports";

my $send_command = "cat call.txt | mail -s \"".$summary."\"";
# @destinataries should never be empty as we have reports with mail
# contacts every quarter, but we test it anyway: we do not want to assume
# that this will be true forever
$send_command = $send_command.' -c '.(join ',', @destinataries) if(@destinataries);
$send_command = $send_command.' quarterly-calls@FreeBSD.org';

if($options{'t'})
{
	print <<EOT;
send_command: $send_command
summary: $summary
call.txt:
EOT
	open(call_mail, '<', 'call.txt') or
	die "Could not open call.txt: $!";
	print <call_mail>;
}
else
{
	system $send_command;
}

unlink "call.txt";
