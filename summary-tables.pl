#!/usr/bin/env perl
use File::Temp qw/ tempfile tempdir /;

use CheckSpelling::Util;

unless (eval 'use URI::Escape; 1') {
    eval 'use URI::Escape::XS qw/uri_escape/';
}

my $budget = CheckSpelling::Util::get_val_from_env("summary_budget", "");
print STDERR "Summary Tables budget: $budget\n";
my $summary_tables = tempdir();
my $table;
my @tables;

sub github_blame {
    my ($file, $line) = @_;

    my $prefix = '';
    my $line_delimiter = ':';
    if ($ENV{GITHUB_SERVER_URL} ne '' && $ENV{GITHUB_REPOSITORY} ne '') {
        my $url_base = "$ENV{GITHUB_SERVER_URL}/$ENV{GITHUB_REPOSITORY}/blame";
        my $rev = $ENV{GITHUB_HEAD_REF} || $ENV{GITHUB_SHA};
        $prefix = "$url_base/$rev/";
        $line_delimiter = '#L';
    }

    if ($file =~ m{^https://}) {
        $file =~ s/ /%20/g;
        return "$file#$line";
    }

    $file = uri_escape($file, "^A-Za-z0-9\-\._~/");
    return "$prefix$file$line_delimiter$line";
}

while (<>) {
    next unless m{^(.+):(\d+):(\d+) \.\.\. (\d+),\s(Error|Warning|Notice)\s-\s(.+)\s\(([-a-z]+)\)$};
    my ($file, $line, $column, $endColumn, $severity, $message, $code) = ($1, $2, $3, $4, $5, $6, $7);
    my $table_file = "$summary_tables/$code";
    push @tables, $code unless -e $table_file;
    open $table, ">>", $table_file;
    $message =~ s/\|/\\|/g;
    my $blame = github_blame($file, $line);
    print $table "$message | $blame\n";
    close $table;
}
exit unless @tables;

my ($details_prefix, $footer, $suffix) = (
    "<details><summary>Details :mag_right:</summary>\n\n",
    "</details>\n\n",
    "\n</details>\n\n"
);
my $footer_length = length $footer;
if ($budget) {
    $budget -= length $details_prefix + length $suffix;
    print STDERR "Summary Tables budget reduced to: $budget\n";
}
for $table_file (sort @tables) {
    my $header = "<details><summary>:open_file_folder: $table_file</summary>\n\n".
        "note|path\n".
        "-|-\n";
    my $header_length = length $header;
    my $file_path = "$summary_tables/$table_file";
    my $cost = $header_length + $footer_length + -s $file_path;
    if ($budget && ($budget < $cost)) {
        print STDERR "::warning title=summary-table::Details for '$table_file' too big to include in Step Summary. (summary-table-skipped)\n";
        next;
    }
    open $table, "<", $file_path;
    my @entries;
    my $real_cost = $header_length + $footer_length;
    foreach my $line (<$table>) {
        $real_cost += length $line;
        push @entries, $line;
    }
    close $table;
    if ($real_cost > $cost) {
        print STDERR "budget ($real_cost > $cost)\n";
        if ($budget && ($budget < $real_cost)) {
            print STDERR "::warning title=summary-tables::budget exceeded for $table_file (summary-table-skipped)\n";
            next;
        }
    }
    if ($details_prefix ne '') {
        print $details_prefix;
        $details_prefix = '';
    }
    print $header;
    print join ("", sort CheckSpelling::Util::case_biased @entries);
    print $footer;
    if ($budget) {
        $budget -= $cost;
        print STDERR "Summary Tables budget reduced to: $budget\n";
    }
}
print $suffix;
