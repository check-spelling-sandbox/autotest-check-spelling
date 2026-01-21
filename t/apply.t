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
  return parse_outputs($stdout, $stderr, @results);
}

sub parse_outputs {
  my ($stdout, $stderr, @results) = @_;
  our $spellchecker;
  $stdout =~ s!$spellchecker/apply\.pl!SPELLCHECKER/apply.pl!g;
  $stderr =~ s!$spellchecker/apply\.pl!SPELLCHECKER/apply.pl!g;
  $stdout =~ s!Current apply script differs from '.*?/apply\.pl' \(locally downloaded to \`.*`\)\. You may wish to upgrade\.\n!!;

  my $result = $results[0] >> 8;
  return ($stdout, $stderr, $result);
}

my $expired_artifacts = "$temp.artifacts";
my $expired_artifacts_log = "$temp.artifacts.log";
my $expired_artifact = '';
my $expired_artifact_repo = 'check-spelling/check-spelling';
my $state = 0;
my $api_url = 'https://api.github.com/repos/check-spelling-sandbox/autotest-check-spelling/actions/artifacts?name=check-spelling-comment';
my $jq_expired_artifacts_log = "$temp.jq.artifacts.log";
my $jq_expression = '.artifacts | map(select (.expired == true))[0].workflow_run.id // empty';

my $retries = 0;
my $GH_TOKEN = $ENV{GH_TOKEN};
unless (defined $GH_TOKEN) {
  $GH_TOKEN = `gh auth token`;
  chomp $GH_TOKEN;
}

# three possible passes (not counting retries for rate limits):
# 1. parse for artifact id
# 2. repository renamed (need to store updated repository id)
# 3. artifacts paginated
while ($state < 4) {
  `curl -s -H "Authorization: token $GH_TOKEN" '$api_url' -o '$expired_artifacts' -D '$expired_artifacts_log'`;
  if (-s $expired_artifacts) {
    $expired_artifact = `grep -q '"artifacts":' '$expired_artifacts' && jq -r '$jq_expression' '$expired_artifacts' 2> '$jq_expired_artifacts_log' || touch '$jq_expired_artifacts_log'`;
    if ($?) {
      print STDERR "jq $jq_expression failed: ".`cat '$jq_expired_artifacts_log'`;
    } else {
      if ($expired_artifact =~ /^(\d+).*/) {
        $expired_artifact = $1;
        my $expired_artifact_url = `jq -r '.artifacts[] | select (.workflow_run.id==$expired_artifact) | .url' '$expired_artifacts'`;
        if ($expired_artifact_url =~ m{([^/]+/[^/]+)/actions/artifacts/\d+$}) {
          $expired_artifact_repo = $1;
        }
        last;
      }
    }
  }
  if (open(my $expired_artifacts_log_fh, '<', $expired_artifacts_log)) {
    my $http_state=0;
    while (<$expired_artifacts_log_fh>) {
      if (/^location: (.*)/) {
        $api_url = $1;
        $state++;
        last;
      }
      if (s/^link:\s+//) {
        s/,\s*/\n/g;
        if (/<(.*?)>; rel="last"/) {
          $api_url = $1;
          $state++;
          last;
        }
      }
      if (m{^HTTP/2 403}) {
        $http_state=403;
        ++$retries;
        last if $retries == 3;
      } elsif ($http_state == 403 && m/^x-ratelimit-remaining: 0/) {
        my $sleep_delay=10+(rand(10) | 0);
        print STDERR "Hit rate limit. Sleeping $sleep_delay seconds\n";
        sleep $sleep_delay;
        last;
      }
    }
    close($expired_artifacts_log_fh);
  }
}

SKIP: {
  skip 'could not find an expired artifact', 3 unless $expired_artifact;
  ($stdout, $stderr, $result) = run_apply("$spellchecker/apply.pl", $expired_artifact_repo, $expired_artifact);

  my $sandbox_name = basename $sandbox;
  my $temp_name = basename $temp;
  is($stdout, "SPELLCHECKER/apply.pl: GitHub Run Artifact expired. You will need to trigger a new run.\n", 'apply.pl (stdout) expired');
  is($stderr, '', 'apply.pl (stderr) expired');
  is($result, 1, 'apply.pl (exit code) expired');
}

($stdout, $stderr, $result) = run_apply("$spellchecker/apply.pl", "https://github.com/check-spelling/imaginary-repository/actions/runs/$expired_artifact/attempts/1");
like($stdout, qr{The referenced repository \(check-spelling/imaginary-repository\) may not exist, perhaps you do not have permission to see it\.\s+If the repository is hosted by GitHub Enterprise, check-spelling does not know how to integrate with it\.}, 'apply.pl (stdout) imaginary-repository');
is($stderr, '', 'apply.pl (stderr) imaginary-repository');
is($result, 8, 'apply.pl (exit code) imaginary-repository');

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
  mkdir "$sandbox/.config/gh";
  `cp -R '$real_home/.config/gh/'* '$sandbox/.config/gh/'`;
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
