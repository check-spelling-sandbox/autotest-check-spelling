#!/usr/bin/env -S perl -w -Ilib

use strict;
use warnings;
use utf8;
use File::Basename;
use Cwd qw/ abs_path /;

use Test::More;
use Capture::Tiny ':all';
use File::Temp qw/ tempfile tempdir /;

plan tests => 6;

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

my ($fd, $name) = tempfile;
print $fd "hello (Hello, hello)\nmeow\n";
close ($fd);
my $collated = $name;
($fd, $name) = tempfile;
print $fd "
`hello` not a recognized word (unrecognized-spelling)
`Hello` not a recognized word (unrecognized-spelling)
something else (something-else)
";

close ($fd);

($stdout, $stderr, @results) = capture {
  system("$ENV{spellchecker}/expect-collator.pl $collated $name");
};

is($stdout, q<`Hello` ignored by check-spelling because another more general variant is also in expect (ignored-expect-variant)
something else (something-else)
>, 'expect-collator out');
is($stderr, '', 'expect-collator err');
is((join ':', @results), '0', 'expect-collator result');
