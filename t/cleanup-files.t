#!/usr/bin/env -S perl -w -Ilib

use strict;
use warnings;
use utf8;

use Cwd qw/ abs_path getcwd realpath /;
use File::Copy;
use File::Temp qw/ tempfile tempdir /;
use File::Basename;
use Test::More;
use Capture::Tiny ':all';

plan tests => 8;

my $spellchecker = dirname(dirname(abs_path(__FILE__)));
$ENV{spellchecker} = $spellchecker;

my $sandbox = tempdir();
`perl -MDevel::Cover -e 1 2>&1`;
$ENV{PERL5OPT} = '-MDevel::Cover' unless $?;
$ENV{GITHUB_WORKSPACE} = $sandbox;
chdir $sandbox;
my ($fh, $temp) = tempfile();
close $temp;
$ENV{maybe_bad} = $temp;
my ($stdout, $stderr, @results);
($stdout, $stderr, @results) = capture {
  system("early_warnings=/dev/stderr output=/dev/stdout ${spellchecker}/wrappers/cleanup-files '$temp'");
};

my $sandbox_name = basename $sandbox;
my $temp_name = basename $temp;
like($stdout, qr!::error ::Configuration files must live within .*?$sandbox_name\.\.\.!, 'cleanup-file.pl (stdout) sandbox');
like($stdout, qr!::error ::Unfortunately, file '[\w/]+?/$temp_name' appears to reside elsewhere\.!, 'cleanup-file.pl (stdout) temp');
is($stderr, '', 'cleanup-file.pl (stderr)');
my $result = $results[0] >> 8;
is($result, 3, 'cleanup-file.pl (exit code)');

my $git_dir = "$sandbox/.git";
mkdir $git_dir;
my $git_child = "$sandbox/.git/bad";

($stdout, $stderr, @results) = capture {
  system("early_warnings=/dev/stderr output=/dev/stdout ${spellchecker}/wrappers/cleanup-files '$git_child'");
};
like($stdout, qr!::error ::Configuration files must not live within \`\.git/\`\.\.\.!, 'cleanup-file.pl (stdout) sandbox');
like($stdout, qr!::error ::Unfortunately, file '[\w/]+?/\.git/bad' appears to\.!, 'cleanup-file.pl (stdout) temp');
is($stderr, '', 'cleanup-file.pl (stderr)');
$result = $results[0] >> 8;
is($result, 4, 'cleanup-file.pl (exit code)');
