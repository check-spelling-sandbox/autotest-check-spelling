#!/usr/bin/env -S perl -w -Ilib

use strict;
use warnings;
use utf8;
use File::Basename;
use Cwd qw/ abs_path /;

use Test::More;
use Capture::Tiny ':all';

plan tests => 3;

my $spellchecker = abs_path(dirname(dirname(__FILE__)));
$ENV{spellchecker} = $spellchecker;

my ($stdout, $stderr, @results) = capture {
  system("
  echo 'hello (Hello, hello)
world' |
  $ENV{spellchecker}/strip-word-collator-suffix.pl");
};

is($stdout, "hello\nworld\n", 'strip-word-collator-suffix out');
is($stderr, '', 'strip-word-collator-suffix err');
is((join ':', @results), '0', 'strip-word-collator-suffix result');
