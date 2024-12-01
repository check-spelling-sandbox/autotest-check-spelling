#!/usr/bin/env -S perl -Ilib

use strict;
use warnings;

use File::Basename;
use File::Temp qw/ tempfile /;
use Test::More;

plan tests => 3;
use_ok('CheckSpelling::Sarif');

is(CheckSpelling::Sarif::encode_low_ascii("\x05"), '\u0005');

my $tests = dirname(__FILE__);
my $base = dirname($tests);

$ENV{'CHECK_SPELLING_VERSION'} = '0.0.0';
my ($fh, $sarif_merged, $warnings);
($fh, $warnings) = tempfile();
print $fh 't/Sarif.t:11:24 ... 29, Error - `Sarif` is not a recognized word. (unrecognized-spelling)
t/Sarif.t:21:14 ... 19, Error - `Sarif` is not a recognized word. (unrecognized-spelling)
t/Sarif.t:21:45 ... 50, Error - `Sarif` is not a recognized word. (unrecognized-spelling)
https://example.com/lib/CheckSpelling/Sarif.pm:3:24 ... 28, Error - `Star` is not a recognized word. (unrecognized-spelling)

';
close $fh;
$ENV{'warning_output'} = $warnings;
($fh, $sarif_merged) = tempfile();
print $fh CheckSpelling::Sarif::main("$base/sarif.json","$tests/sarif.json", 'check-spelling/test');
close $fh;
my $formated_sarif;
($fh, $formated_sarif) = tempfile();
close $fh;
`jq -M . '$sarif_merged'|perl -pe 's/^\\s*//' > '$formated_sarif'`;

$ENV{'HOME'} =~ /^(.*)$/;
my $home = $1;
$ENV{'PATH'} = "/bin:$home/.extra-bin";
my $jd_output = `jd -set -setkeys uri,startLine,startColumn,endColumn '$tests/sarif.json.expected' '$formated_sarif'`;
is($jd_output, '');
