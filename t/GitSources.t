#!/usr/bin/env -S perl -w -Ilib

use strict;
use warnings;

use Cwd qw(getcwd);
use Test::More;
use File::Temp qw/ tempfile tempdir /;
use Capture::Tiny ':all';

plan tests => 17;
use_ok('CheckSpelling::GitSources');

is(CheckSpelling::GitSources::github_repo(
    'https://github.com/some/thing.git'), 'some/thing', 'github_repo https');
is(CheckSpelling::GitSources::github_repo(
    'git@github.com:some/thing'), 'some/thing', 'github_repo ssh');
is(CheckSpelling::GitSources::github_repo(
    '../some/thing'), '', 'github_repo relative');

my $working_directory = getcwd();
my $git_user='example';
my $git_email='user@example.com';
my $git_configs="-c user.name=$git_user -c user.email=$git_email";
my $git_root = tempdir(CLEANUP => 1);
my $git_root_url = 'https://github.com/check-spelling-sandbox/git-sources-1';
chdir $git_root;

`
set -e
git -c init.defaultBranch=main init;
git remote add origin '$git_root_url';
touch a; git add a; git $git_configs commit -m a;
`;
is($?, 0, 'git root init worked');
my $child1 = "$git_root/child1";
mkdir $child1;
chdir $child1;
my $child1_url = 'git@github.com/check-spelling-sandbox/git-sources-2';
my $child1_branch = 'something';

`
set -e
git -c init.defaultBranch=$child1_branch init;
git remote add origin '$child1_url'.git;
mkdir next; touch a b next/c; git add a b next/c; git $git_configs commit -m a;
`;
is($?, 0, 'git child1 init worked');

chdir $git_root;
my ($file, $git_base_dir, $prefix, $remote_url, $rev, $branch) = CheckSpelling::GitSources::git_source_and_rev("a");
is($file, 'a', "git_root file");
is($remote_url, $git_root_url, "git_root remote_url");
is($branch, 'main', "git_root branch");
is($git_base_dir, '.', "git_root git_base_dir");

($file, $git_base_dir, $prefix, $remote_url, $rev, $branch) = CheckSpelling::GitSources::git_source_and_rev("child1/a");
is($file, 'a', "child1 a");
is($git_base_dir, 'child1', "child1 git_base_dir");

($file, $git_base_dir, $prefix, $remote_url, $rev, $branch) = CheckSpelling::GitSources::git_source_and_rev("child1/b");
is($file, 'b', "child1 b");
is($git_base_dir, 'child1', "child1 git_base_dir");

($file, $git_base_dir, $prefix, $remote_url, $rev, $branch) = CheckSpelling::GitSources::git_source_and_rev("child1/next/c");
is($file, 'next/c', "child1 file");
is($remote_url, $child1_url, "child1 next/c");
is($git_base_dir, 'child1', "child1 git_base_dir");
chdir $working_directory;
