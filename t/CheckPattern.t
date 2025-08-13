#!/usr/bin/env -S perl -w -Ilib

use strict;
use warnings;

use Cwd qw/ abs_path realpath /;
use File::Copy;
use File::Temp qw/ tempfile tempdir /;
use File::Basename;
use Test::More;
use Capture::Tiny ':all';
plan tests => 5;
use_ok('CheckSpelling::CheckPattern');

my ($out, $err) = CheckSpelling::CheckPattern::process_line("hello\n");
is ($out, "hello");
is ($err, '');

($out, $err) = CheckSpelling::CheckPattern::process_line("+foo");
is ($out, "^\$\n");
is ($err, "1 ... 2, Warning - Quantifier follows nothing: `+`. (bad-regex)\n");

# ($out, $err) = CheckSpelling::CheckPattern::process_line("x{\n");
# is ($out, "hello");
# is ($err, '');

