#!/usr/bin/env -S perl -w -Ilib

use strict;
use warnings;

use Cwd qw/ abs_path getcwd realpath /;
use File::Copy;
use File::Temp qw/ tempfile tempdir /;
use File::Basename;
use Test::More;
use Capture::Tiny ':all';

plan tests => 17;

our $spellchecker = dirname(dirname(abs_path(__FILE__)));

my $sandbox = tempdir();
chdir($sandbox);
`perl -MDevel::Cover -e 1 2>&1`;
$ENV{PERL5OPT} = '-MDevel::Cover' unless $?;
$ENV{GITHUB_WORKSPACE} = $sandbox;
my ($fh, $temp) = tempfile();
close $fh;
$ENV{maybe_bad} = $temp;
my ($stdout, $stderr, $result);

sub run_apply {
  my @args = @_;
  my ($stdout, $stderr, @results) = capture {
    system(@args);
  };
  our $spellchecker;
  $stdout =~ s!$spellchecker/apply\.pl!SPELLCHECKER/apply.pl!g;
  $stderr =~ s!$spellchecker/apply\.pl!SPELLCHECKER/apply.pl!g;
  $stdout =~ s!Current apply script differs from '.*?/apply\.pl' \(locally downloaded to \`.*`\)\. You may wish to upgrade\.\n!!;

  my $result = $results[0] >> 8;
  return ($stdout, $stderr, $result);
}

my $expired_artifacts = "$temp.artifacts";
my $expired_artifacts_log = "$temp.artifacts.log";
my $gh_api_call = '/repos/check-spelling/check-spelling/actions/artifacts?name=check-spelling-comment';
my $expired_artifact = '';
`gh api '$gh_api_call' > '$expired_artifacts' 2> '$expired_artifacts_log'`;
if ($?) {
  print STDERR "gh api $gh_api_call failed: ".`cat '$expired_artifacts_log'`;
} else {
  my $jq_expired_artifacts_log = "$temp.jq.artifacts.log";
  my $jq_expression = '.artifacts | map(select (.expired == true))[0].workflow_run.id // empty';
  $expired_artifact = `jq -r '$jq_expression' '$expired_artifacts' 2> '$jq_expired_artifacts_log'`;
  if ($?) {
    print STDERR "jq $jq_expression failed: ".`cat '$jq_expired_artifacts_log'`;
  } else {
    chomp $expired_artifact;
    ($stdout, $stderr, $result) = run_apply("$spellchecker/apply.pl", 'check-spelling/check-spelling', $expired_artifact);

    my $sandbox_name = basename $sandbox;
    my $temp_name = basename $temp;
    is($stdout, "SPELLCHECKER/apply.pl: GitHub Run Artifact expired. You will need to trigger a new run.\n", 'apply.pl (stdout) expired');
    is($stderr, '', 'apply.pl (stderr) expired');
    is($result, 1, 'apply.pl (exit code) expired');
  }
}

($stdout, $stderr, $result) = run_apply("$spellchecker/apply.pl", "https://localhost/check-spelling/imaginary-repository/actions/runs/$expired_artifact/attempts/1");
like($stdout, qr{The referenced repository \(check-spelling/imaginary-repository\) may not exist, perhaps you do not have permission to see it\.\s+If the repository is hosted by GitHub Enterprise, check-spelling does not know how to integrate with it\.}, 'apply.pl (stdout) localhost-url');
is($stderr, '', 'apply.pl (stderr) localhost-url');
is($result, 8, 'apply.pl (exit code) localhost-url');

my $gh_token = $ENV{GH_TOKEN};
delete $ENV{GH_TOKEN};
my $real_home = $ENV{HOME};
my $real_http_socket = `gh config get http_unix_socket`;
$ENV{HOME} = $sandbox;
($stdout, $stderr, $result) = run_apply("$spellchecker/apply.pl", 'check-spelling/check-spelling', $expired_artifact);

like($stdout, qr{gh auth login|set the GH_TOKEN environment variable}, 'apply.pl (stdout) not authenticated');
like($stderr, qr{SPELLCHECKER/apply.pl requires a happy gh, please try 'gh auth login'}, 'apply.pl (stderr) not authenticated');
is($result, 1, 'apply.pl (exit code) not authenticated');
$ENV{GH_TOKEN} = $gh_token;

if (-d "$real_home/.config/gh/") {
  mkdir "$sandbox/.config";
  `rsync -a '$real_home/.config/gh/' '$sandbox/.config/gh/'`;
}

`gh config set http_unix_socket /dev/null`;
($stdout, $stderr, $result) = run_apply("$spellchecker/apply.pl", 'check-spelling/check-spelling', $expired_artifact);

like($stdout, qr{SPELLCHECKER/apply.pl: Unix http socket is not working\.}, 'apply.pl (stdout) bad_socket');
like($stdout, qr{http_unix_socket: /dev/null}, 'apply.pl (stdout) bad_socket');
is($stderr, '', 'apply.pl (stderr) bad_socket');
is($result, 7, 'apply.pl (exit code) bad_socket');
$ENV{HOME} = $real_home;

`gh config set http_unix_socket '$real_http_socket'`;

$ENV{https_proxy}='http://localhost:9123';
($stdout, $stderr, $result) = run_apply("$spellchecker/apply.pl", 'check-spelling/check-spelling', $expired_artifact);

like($stdout, qr{SPELLCHECKER/apply.pl: Proxy is not accepting connections\.}, 'apply.pl (stdout) bad_proxy');
like($stdout, qr{https_proxy: 'http://localhost:9123'}, 'apply.pl (stdout) bad_proxy');
is($stderr, '', 'apply.pl (stderr) bad_proxy');
is($result, 6, 'apply.pl (exit code) bad_proxy');
