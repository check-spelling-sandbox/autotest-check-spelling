#!/usr/bin/env -S perl -w -Ilib

use strict;
use warnings;
no warnings 'once';
no warnings 'redefine';

use utf8;

use Cwd qw();
use Test::More;
use File::Temp qw/ tempfile tempdir /;

plan tests => 32;
use_ok('CheckSpelling::Yaml');

is(CheckSpelling::Yaml::get_yaml_value(
    'no-such-action.yml', 'name'), '', 'no such file');

is(CheckSpelling::Yaml::get_yaml_value(
    'action.yml', 'name'), '"Check Spelling"', 'action name');

is(CheckSpelling::Yaml::get_yaml_value('action.yml', 'inputs.largest_file.default'), '"1048576"', 'inputs.largest_file.default');

is(CheckSpelling::Yaml::get_yaml_value('action.yml', 'inputs.shortest_word.default'), '"3"', 'inputs.shortest_word.default');

like(CheckSpelling::Yaml::get_yaml_value('action.yml', 'inputs.event_aliases.description'), qr{\. If}, 'multiline >-');

is(CheckSpelling::Yaml::get_yaml_value('t/yaml/test.yml', 'this.that'), "x\n\ny\n", 'multiline |');

open my $oldin, '<&', \*STDIN or die "Can't dup STDIN:$!";

my $yaml_content = '
parent:
  items:
  - a
  - b
  # foo: bar
fruit: apple
berry: |
  blue
wine: white
fruit: >
  salad
tree: pear
';

my $invar = $yaml_content;

our $triggered = 0;

*CheckSpelling::Yaml::report = sub {
    my ($file, $start_line, $start_pos, $end, $message, $match, $report_match) = @_;
    is($file, '-', 'report_match=1 (file)');
    is($start_line, 10, 'report_match=1 (start line)');
    is($start_pos, 1, 'report_match=1 (start pos)');
    is($end, 12, 'report_match=1 (end)');
    is($message, 'Good work', 'report_match=1 (message)');
    is($match, 'wine: white', 'report_match=1 (match)');
    is($report_match, 1, 'report_match=1 (report match)');
    ++$main::triggered;
};

CheckSpelling::Yaml::check_yaml_key_value('wine', 'white', 'Good work', 1, '-', $yaml_content);
is($triggered, 1, 'should call CheckSpelling::Yaml::report (wine: white)');

$triggered = 0;
*CheckSpelling::Yaml::report = sub {
    my ($file, $start_line, $start_pos, $end, $message, $match, $report_match) = @_;
    is($file, '-', 'report_match=0 (file)');
    is($start_line, 11, 'report_match=0 (start line)');
    is($start_pos, 1, 'report_match=0 (start pos)');
    is($end, 16, 'report_match=0 (end)');
    is($message, 'Good night', 'report_match=0 (message)');
    is($match, 'fruit: salad', 'report_match=0 (match)');
    is($report_match, 0, 'report_match=0 (report match)');
    ++$main::triggered;
};

CheckSpelling::Yaml::check_yaml_key_value('fruit', 'salad', 'Good night', 0, '-', $yaml_content);
is($triggered, 1, 'should call CheckSpelling::Yaml::report (fruit: salad)');

$triggered = 0;
*CheckSpelling::Yaml::report = sub {
    my ($file, $start_line, $start_pos, $end, $message, $match, $report_match) = @_;
    is($file, '-');
    is($start_line, 8);
    is($start_pos, 1);
    is($end, 15);
    is($message, 'Good night');
    is($match, "berry: |\n  blue");
    is($report_match, 1);
    ++$main::triggered;
};

CheckSpelling::Yaml::check_yaml_key_value('berry', 'blue', 'Good night', 1, '-', $yaml_content);
is($triggered, 1, 'should call CheckSpelling::Yaml::report (berry: blue)');

$triggered = 0;
*CheckSpelling::Yaml::report = sub {
    my ($file, $start_line, $start_pos, $end, $message, $match, $report_match) = @_;
    ++$main::triggered;
};

CheckSpelling::Yaml::check_yaml_key_value('juice', 'apple', 'No work', 1, '-', $yaml_content);
is($triggered, 0, 'should not call CheckSpelling::Yaml::report');
close STDIN;

open STDIN, '<&', $oldin;
