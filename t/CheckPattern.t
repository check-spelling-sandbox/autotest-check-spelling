#!/usr/bin/env -S perl -w -Ilib

use strict;
use warnings;

use Cwd qw/ abs_path realpath /;
use File::Copy;
use File::Temp qw/ tempfile tempdir /;
use File::Basename;
use Test::More;
use Capture::Tiny ':all';
plan tests => 9;
use_ok('CheckSpelling::CheckPattern');

my ($out, $err) = CheckSpelling::CheckPattern::process_line("hello\n");
is ($out, "hello");
is ($err, '');

my $invalid_regex = "^\$\n";

($out, $err) = CheckSpelling::CheckPattern::process_line("+foo");
is ($out, $invalid_regex);
is ($err, "1 ... 2, Warning - Quantifier follows nothing: `+`. (bad-regex)\n");

($out, $err) = CheckSpelling::CheckPattern::process_line("x{\n");
is ($out, $invalid_regex);
is ($err, "2 ... 3, Warning - Unescaped left brace in regex is passed through: `x{`. (bad-regex)\n");

($out, $err) = CheckSpelling::CheckPattern::process_line("x{a{\n");
is ($out, $invalid_regex);
is ($err, "4 ... 5, Warning - Unescaped left brace in regex is passed through: `x{a{`. (bad-regex)\n");
