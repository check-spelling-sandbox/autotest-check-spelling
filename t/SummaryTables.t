#!/usr/bin/env -S perl -w -Ilib

use strict;
use warnings;
use utf8;

use Cwd qw();
use open ':std', ':encoding(UTF-8)';
use Test::More;
use File::Temp qw/ tempfile tempdir /;
use Capture::Tiny ':all';

my $builder = Test::More->builder;
binmode $builder->output,         ":utf8";
binmode $builder->failure_output, ":utf8";
binmode $builder->todo_output,    ":utf8";

plan tests => 17;
use_ok('CheckSpelling::SummaryTables');

is(CheckSpelling::SummaryTables::file_ref(
    'file name', 20), 'file%20name:20', 'file ref');

$ENV{summary_budget} = 0;

my $origin = Cwd::cwd();

my $test_git_root = tempdir();

chdir $test_git_root;

my $owner_repo='https://github.com/owner/example';
my $other_repo='git@github.com:another/place.git';
my $name='first last';
my $email='first.last@example.com';
my $ref;
`
git init --initial-branch=main .;
git config user.name '$name';
git config user.email '$email';
git remote add origin '$owner_repo';
touch README.md;
git add README.md;
git commit -m README;
git clone -q . child;
GIT_DIR=child/.git git remote set-url origin '$other_repo';
echo >> README.md;
git commit -m blank;
`;

$ref = `git rev-parse HEAD`;
chomp $ref;
is(CheckSpelling::SummaryTables::github_blame("http://example.com/file", 2), 'http://example.com/file:2', 'github_blame url');
is(CheckSpelling::SummaryTables::github_blame(
    'README.md', 1), "https://github.com/owner/example/blame/$ref/README.md#L1",
    'github_blame root');
$ref = `GIT_DIR=child/.git git rev-parse HEAD`;
chomp $ref;
is(CheckSpelling::SummaryTables::github_blame(
    'child/README.md', 1), "https://github.com/another/place/blame/$ref/README.md#L1",
    'github_blame child');

my $oldIn = *ARGV;
my $text = 'file.yml:1:1 ... 1, Warning - Unsupported configuration: use_sarif needs security-events: write (unsupported-configuration)
file.yml:2:1 ... 1, Warning - Unsupported configuration: use_sarif needs security-events: write (alternate-configuration)
file.yml:3:1 ... 1, Warning - Unsupported configuration: use_sarif needs security-events: write (alternate-configuration)
file.yml:4:1 ... 1, Warning - Unsupported configuration: use_sarif needs security-events: write (alternate-configuration)
file.yml:5:1 ... 1, Warning - Unsupported configuration: use_sarif needs security-events: write (some-configuration)

';
$ENV{'GITHUB_HEAD_REF'} = 'test-ref';
$ENV{'GITHUB_SERVER_URL'} = 'http://github.localdomain';
$ENV{'GITHUB_REPOSITORY'} = 'owner/repo';
$ENV{'GITHUB_EVENT_PATH'} = "$origin/t/summary-table-main/event-path.json";
my $head = `GIT_DIR=.git git rev-parse HEAD`;
chomp $head;

open my $input, '<', \$text;
*ARGV = $input;
$ENV{'summary_budget'} = 600;
my ($stdout, $stderr, $result) = capture {
CheckSpelling::SummaryTables::main();
};
is($stdout, "<details><summary>Details 🔎</summary>

<details><summary>📂 some-configuration</summary>

note|path
-|-
Unsupported configuration: use_sarif needs security-events: write | https://github.com/owner/example/blame/$head/file.yml#L5
</details>

<details><summary>📂 unsupported-configuration</summary>

note|path
-|-
Unsupported configuration: use_sarif needs security-events: write | https://github.com/owner/example/blame/$head/file.yml#L1
</details>


</details>

", 'summary output (budget: 600)');
is($stderr, "Summary Tables budget: 600
Summary Tables budget reduced to: 548
::warning title=summary-table::Details for 'alternate-configuration' too big to include in Step Summary (summary-table-skipped)
Summary Tables budget reduced to: 312
Summary Tables budget reduced to: 69
", 'summary error (budget: 600)');
is($result, 1, 'summary result (budget: 600)');
close $input;

open $input, '<', \$text;
$ENV{'summary_budget'} = 100;
($stdout, $stderr, $result) = capture {
CheckSpelling::SummaryTables::main();
};
is($stderr, q<Summary Tables budget: 100
Summary Tables budget reduced to: 48
::warning title=summary-table::Details for 'alternate-configuration' too big to include in Step Summary (summary-table-skipped)
::warning title=summary-table::Details for 'some-configuration' too big to include in Step Summary (summary-table-skipped)
::warning title=summary-table::Details for 'unsupported-configuration' too big to include in Step Summary (summary-table-skipped)
>, 'summary error (budget: 100)');
is($stdout, '', 'summary output (budget: 100)');
is($result, 0, 'summary result (budget: 100)');
close $input;

open $input, '<', \$text;
$ENV{'GITHUB_REPOSITORY'} = 'another/repo';
($stdout, $stderr, $result) = capture {
CheckSpelling::SummaryTables::main();
};
is($stderr, q<Summary Tables budget: 100
Summary Tables budget reduced to: 48
::warning title=summary-table::Details for 'alternate-configuration' too big to include in Step Summary (summary-table-skipped)
::warning title=summary-table::Details for 'some-configuration' too big to include in Step Summary (summary-table-skipped)
::warning title=summary-table::Details for 'unsupported-configuration' too big to include in Step Summary (summary-table-skipped)
>, 'summary error another/repo');
is($stdout, '', 'summary output another/repo');
is($result, 0, 'summary result another/repo');
close $input;

$text = '';
open $input, '<', \$text;
$ENV{'GITHUB_REPOSITORY'} = 'another/repo';
($stdout, $stderr, $result) = capture {
CheckSpelling::SummaryTables::main();
};
is($stderr, q<Summary Tables budget: 100
>, 'summary error (empty)');
is($stdout, '', 'summary output (empty)');
is($result, undef, 'summary result (empty)');
close $input;


*ARGV = $oldIn;
