#!/usr/bin/env -S perl -w -Ilib

use strict;
use warnings;
use utf8;
use File::Basename;
use Cwd qw/ abs_path /;

use Test::More;
use Capture::Tiny ':all';
use File::Temp qw/ tempfile tempdir /;

plan tests => 14;

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

$ENV{GITHUB_WORKSPACE}='/lib';
($stdout, $stderr, @results) = capture {
  system("maybe_bad=/etc/passwd $ENV{spellchecker}/cleanup-file.pl");
};

like($stdout, qr<::error ::Configuration files must live within .*\.\.\.>, 'cleanup-file out must live within');
like($stdout, qr<::error ::Unfortunately, file .* appears to reside elsewhere.>, 'cleanup-file out resides elsewhere');
is($stderr, '', 'cleanup-file elsewhere err');
is($results[0] >> 8, 3, 'cleanup-file elsewhere result');

my $dir=tempdir;
$ENV{GITHUB_WORKSPACE}=$dir;
($stdout, $stderr, @results) = capture {
  system("
    git init -q '$dir';
    maybe_bad=$dir/.git/config $ENV{spellchecker}/cleanup-file.pl
  ");
};

like($stdout, qr<::error ::Configuration files must not live within `\.git/`\.\.\.>, 'cleanup-file out must not live within');
like($stdout, qr<::error ::Unfortunately, file .*/\.git/config appears to\.>, 'cleanup-file out appears to');
is($stderr, '', 'cleanup-file .git err');
is($results[0] >> 8, 4, 'cleanup-file .git result');
