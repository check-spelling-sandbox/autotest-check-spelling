#! -*-perl-*-

package CheckSpelling::Yaml;

our $VERSION='0.1.0';
use CheckSpelling::Util;

sub report {
  my ($file, $start_line, $start_pos, $end, $message, $match, $report_match) = @_;
  open(my $output, '>>', CheckSpelling::Util::get_file_from_env('output', '/dev/null'));
  if (1 == $report_match) {
    print "$match";
    print $output "$match";
  } else {
    print "$file:$start_line:$start_pos ... $end, $message\n";
    print $output "$file:$start_line:$start_pos ... $end, $message\n";
  }
  close $output;
  exit;
}

sub get_yaml_value {
  my ($file, $path) = @_;
  my @path_split = split /\./, $path;
  my $level = 0;
  my @prefixes;
  open($yaml, '<', $file) || return '';
  my @result;
  my $line_result;
  my $mode;
  my $last;
  while (<$yaml>) {
    chomp;
    next if /^\s*#/;
    if (/^(\s*)(\S.*)/) {
      my ($prefix, $remainder) = ($1, $2);
      while ($level && length $prefix <= length $prefixes[$level - 1]) {
        delete $prefixes[$level--];
      }
      if (@result && $level < scalar @path_split) {
        $last = 1;
        last;
      }
      last if $last;
      if (!$level || length $prefix > length $prefixes[$level - 1]) {
        if ($level == scalar @path_split) {
          push @result, $remainder;
        } else {
          my $next = $path_split[$level];
          if ($remainder =~ /$next:(.*)$/) {
            $prefixes[$level++] = $prefix;
            if ($level == scalar @path_split) {
              $mode = $1;
              if ($mode =~ /\s*([-+>|]+)\s*$/) {
                $mode = $1;
              } elsif ($mode =~ /\s*(\S.*?)\s*$/) {
                my $value = $1;
                $value =~ s/^'(.*)'$/$1/;
                $line_result = $value;
                last;
              }
            }
          }
        }
      }
    } elsif (/^\s*$/ && @result) {
      push @result, '';
    }
  }
  close $yaml;
  return $line_result unless @result;
  my $newlines = '';
  $newlines = $1 if $mode =~ /([-+])/;
  $mode =~ /([|>]?)/;
  $mode = $1;
  my $suffix = '';
  if ($newlines eq '') {
    $suffix = "\n";
  } elsif ($newlines =~ /-/) {
    $suffix = ' ';
  }
  my $empty_lines = 0;
  unless ($newlines eq '+') {
    while ($result[$#result] eq '') {
      ++$empty_lines;
      pop @result;
    }
  }
  if ($mode eq '') {
    return (join ' ', @result).$suffix;
  }
  if ($mode eq '|') {
    return (join "\n", @result).$suffix;
  }
  if ($mode eq '>') {
    my @output;
    my $tentative;
    while (@result) {
      my $line = shift @result;
      if ($line eq '') {
        push @output, $tentative;
        $tentative = '';
      } else {
        $tentative .= $suffix . $line;
      }
    }
    push @output, $tentative;
    return (join "\n", @output).$suffix;
  }
  return (join ' ? ', @result).$suffix;
}

sub check_yaml_key_value {
  my ($key, $value, $message, $report_match, $file, $content) = @_;
  my ($state, $gh_yaml_mode) = (0, '');
  my @nests;
  my ($start_line, $start_pod, $end);
  my @lines = split /\n/, $content;
  my $line = 0;
  my @expected_key_path = split /\n/, $key;
  my @current_key_path;
  $key = quotemeta($key);

  for (@lines) {
    ++$line;
    if (/^(\s*)#/) {
      $end += length $_ if ($state == 3);
      next;
    }
    if ($state == 0) {
      next unless /^(\s*)(-\s+|)(\S+)\s*:/;
      my ($spaces, $array_element, $record) = ($1, $2, $3);
      my $len = length "$spaces$array_element";
      while (scalar @nests && $len < $nests[$#nests]) {
        pop @nests;
      }
      push @nests, $len if (! scalar @nests || $len > $nests[$#nests]);
      if ($#expected_key_path >= 1) {
        $#current_key_path = $#nests;
        $current_key_path[$#nests] = $record;
        next if $#nests != $#expected_key_path;
        my $unequal = 0;
        for my $i (0 .. $#nests) {
          if ($current_key_path[$i] ne $expected_key_path[$i]) {
            $unequal = 1;
            last;
          }
        }
        next if $unequal;
        $key = quotemeta($expected_key_path[$#nests]);
      }
      if (/^\s*(($key)\s*:\s*([|>](?:[-+]\d*)?|\$\{\{.*|(?:"\s*|)$value))\s*$/) {
        $gh_yaml_mode = $3;
        ($start_line, $start_pos, $end, $match) = ($line, $-[2] + 1, $+[3] + 1, $1);
        report($file, $start_line, $start_pos, $end, $message, $match, $report_match) if ($gh_yaml_mode =~ /$value|\$\{\{/);
        if ($report_match) {
          $_ =~ /^\s*(.*)/;
          $match = "$_\n";
        } else {
          $match = "$key: ";
        }
        $state = 1;
      }
    } elsif ($state == 1) {
      if (/^\s*(?:#.*|)$/) {
        $end += length $_;
        next;
      }
      /^(\s*)(\S.*?)\s*$/;
      my ($spaces, $v) = ($1, $2);
      $len = length $spaces;
      if (scalar @nests && $len > $nests[$#nests] && $v =~ /$value/) {
        $end += $len + length $v;
        if ($report_match) {
          $match .= $_;
        } else {
          $match .= $v;
        }
        report($file, $start_line, $start_pos, $end, $message, $match, $report_match);
      }
      pop @nests;
      $state = 0;
    }
  }
}

1;
