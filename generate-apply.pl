#!/usr/bin/env perl
use JSON::PP;
sub read_null_delimited_file {
  my ($file) = @_;
  local $/=undef;
  return () unless open my $input, '<:encoding(UTF-8)', $file;
  my @files = split /\0/, <$input>;
  close $input;
  return @files;
}
my @expect_files = read_null_delimited_file $ENV{expect_files};
my @excludes_files = read_null_delimited_file $ENV{excludes_files};
my $new_expect_file = $ENV{new_expect_file};
my $excludes_file = $ENV{excludes_file};
my $spelling_config = $ENV{spelling_config};
my $job = $ENV{THIS_GITHUB_JOB_ID};
$config{"excludes_file"} = $excludes_file;
$config{"new_expect_file"} = $new_expect_file;
$config{"spelling_config"} = $spelling_config;
$config{"expect_files"} = \@expect_files;
$config{"excludes_files"} = \@excludes_files;
$config{"job"} = $job;
$config{"only_check_changed_files"} = $ENV{INPUT_ONLY_CHECK_CHANGED_FILES};
my $json_canonical = JSON::PP->new->canonical([1]);
print $json_canonical->utf8->encode(\%config);
