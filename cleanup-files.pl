#!/usr/bin/env perl

use Cwd 'realpath';
use File::Spec;
use CheckSpelling::Util;
use CheckSpelling::CheckDictionary;
use CheckSpelling::CheckPattern;
use CheckSpelling::EnglishList;
use Cwd qw(abs_path);

sub identity {
  return @_;
}

sub main {
  my @files = @_;
  my $type=CheckSpelling::Util::get_file_from_env('type');
  my $output=CheckSpelling::Util::get_file_from_env('output', '/dev/null');
  my $workspace_path=abs_path(CheckSpelling::Util::get_file_from_env('GITHUB_WORKSPACE', '.'));
  my $used_config_files=CheckSpelling::Util::get_file_from_env('used_config_files', '/dev/null');
  $ENV{comment_char}='\s*#';
  open our $warnings_fh, '>>:encoding(UTF-8)', CheckSpelling::Util::get_file_from_env('early_warnings', '/dev/null');
  open our $output_fh, '>>:encoding(UTF-8)', $output;
  open my $used_config_files_fh, '>>:encoding(UTF-8)', $used_config_files;
  my $old_file;
  my $check_line;

  if ($type =~ /^(?:line_forbidden|patterns|excludes|only|reject)$/) {
    $check_line = \&CheckSpelling::CheckPattern::process_line;
  } elsif ($type =~ /^(?:dictionary|expect|allow)$/) {
    $check_line = \&CheckSpelling::CheckDictionary::process_line;
  } else {
    $check_line = \&identity;
  }

  for my $file (@files) {
    my $maybe_bad=abs_path($file);
    if ($maybe_bad !~ /^\Q$workspace_path\E/) {
      print "::error ::Configuration files must live within $workspace_path...\n";
      print "::error ::Unfortunately, file '$file' appears to reside elsewhere.\n";
      exit 3;
    }
    if ($maybe_bad =~ m{/\.git/}i) {
      print "::error ::Configuration files must not live within `.git/`...\n";
      print "::error ::Unfortunately, file '$file' appears to.\n";
      exit 4;
    }
    my $fh;
    if (open($fh, '<:encoding(UTF-8)', $file)) {
      $ARGV = $file;
      print $used_config_files_fh "$file\0";
      seek($fh, -1, 2);
      read($fh, $buffer, 1);
      my $length = tell($fh);
      seek($fh, 0, 0);
      my $add_nl_at_eof = 0;
      if ($length == 0) {
        print STDERR "$file:1:1 ... 1, Notice - File is empty (empty-file)\n";
      } else {
        if ($buffer !~ /\R/) {
          print STDERR "$file does not have newline at eof\n";
          $add_nl_at_eof = 1;
        }
        # local $/ = undef;
        my ($nl, $end, $line);
        my %eol_counts;
        my $content = '';
        my ($first_end, $end);
        while (!eof($fh)) {
          read $fh, $buffer, 4096;
          $content .= $buffer;
          while ($content =~ s/([^\r\n\x0b\f\x85\x{2028}\x{2029}]*)(\r\n|\n|\r|\x0b|\f|\x85|\x{2028}|\x{2029})//m) {
            ++$.;
            my ($line, $end) = ($1, $2);
            unless (defined $nl) {
              $nl = $end;
            } elsif ($end ne $nl) {
              print WARNINGS "$file:$.:$-[0] ... $+[0], Warning - Entry has inconsistent line endings (unexpected-line-ending)\n";
            }
            ++$eol_counts{$end};
            my ($line, $warning) = $check_line->($line);
            if ($warning) {
              print $warnings_fh "$file:$.:$warning";
            }
            print $output_fh $line."\n";
          }
        }
        if ($content ne '') {
          my ($line, $warning) = $check_line->($content);
          if ($warning ne '') {
            print $warnings_fh "$file$warning";
          } elsif ($line ne '') {
            print $output_fh "$line\n";
          }
        }
        if ($add_nl_at_eof) {
          my $line_length = length $_;
          print STDERR "$file:$.:1 ... $length, Warning - Missing newline at end of file (no-newline-at-eof)\n";
          print $output_fh "\n";
        }
        my $eol_a = $eol_counts{"\n"} || 0;
        my $eol_d = $eol_counts{"\r"} || 0;
        my $eol_d_a = $eol_counts{"\r\n"} || 0;
        my @line_endings;
        push @line_endings, "DOS [$eol_d_a]" if $eol_d_a;
        push @line_endings, "UNIX [$eol_a]" if $eol_a;
        push @line_endings, "Mac classic [$eol_d]" if $eol_d;
        if (scalar @line_endings > 1) {
          my $line_length = length $_;
          my $mixed_endings = CheckSpelling::EnglishList::build(@line_endings);
          printf STDERR "$file:$.:1 ... $length, Warning - Mixed $mixed_endings line endings (mixed-line-endings)\n";
        }
      }
      close($fh);
    }
  }
  close $used_config_files_fh;
  close $warnings_fh;
}

main(@ARGV);
