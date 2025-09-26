#! -*-perl-*-
package CheckSpelling::SummaryTables;

use Cwd 'abs_path';
use File::Basename;
use File::Temp qw/ tempfile tempdir /;
use JSON::PP;
use CheckSpelling::Util;
use CheckSpelling::GitSources;

unless (eval 'use URI::Escape; 1') {
    eval 'use URI::Escape::XS qw/uri_escape/';
}

my $pull_base;
my $pull_head;

sub file_ref {
    my ($file, $line) = @_;
    $file =~ s/ /%20/g;
    return "$file:$line";
}

sub github_blame {
    my ($file, $line) = @_;
    our (%git_roots, %github_urls, $pull_base, $pull_head);

    return file_ref($file, $line) if ($file =~ m{^https?://});

    my ($prefix, $parsed_file) = CheckSpelling::GitSources::git_source_and_rev($file);
    return file_ref($file, $line) unless defined $prefix;
    my $line_delimiter = $prefix =~ m<https?://> ? '#L' : ':';

    $file = uri_escape($parsed_file, "^A-Za-z0-9\-\._~/");
    return "$prefix$file$line_delimiter$line";
}

sub main {
    my $budget = CheckSpelling::Util::get_val_from_env("summary_budget", "");
    print STDERR "Summary Tables budget: $budget\n";
    my $summary_tables = tempdir();
    my $table;
    my @tables;

    my $head_ref = CheckSpelling::Util::get_file_from_env('GITHUB_HEAD_REF', "");
    my $github_url = CheckSpelling::Util::get_file_from_env('GITHUB_SERVER_URL', "");
    my $github_repository = CheckSpelling::Util::get_file_from_env('GITHUB_REPOSITORY', "");
    my $event_file_path = CheckSpelling::Util::get_file_from_env('GITHUB_EVENT_PATH', "");
    if ($head_ref && $github_url && $github_repository && $event_file_path) {
        if (open $event_file_handle, '<', $event_file_path) {
            local $/;
            my $json = <$event_file_handle>;
            close $event_file_handle;
            my $data = decode_json($json);
            our $pull_base = "$github_url/$github_repository";
            our $pull_head = "$github_url/".$data->{'pull_request'}->{'head'}->{'repo'}->{'full_name'};
            unless ($pull_head && $pull_base && ($pull_base ne $pull_head)) {
                $pull_base = $pull_head = '';
            }
        }
    }

    while (<>) {
        next unless m{^(.+):(\d+):(\d+) \.\.\. (\d+),\s(Error|Warning|Notice)\s-\s(.+)\s\(([-a-z]+)\)$};
        my ($file, $line, $column, $endColumn, $severity, $message, $code) = ($1, $2, $3, $4, $5, $6, $7);
        my $table_file = "$summary_tables/$code";
        push @tables, $code unless -e $table_file;
        open $table, ">>", $table_file;
        $message =~ s/\|/\\|/g;
        my $blame = CheckSpelling::SummaryTables::github_blame($file, $line);
        print $table "$message | $blame\n";
        close $table;
    }
    return unless @tables;

    my ($details_prefix, $footer, $suffix, $need_suffix) = (
        "<details><summary>Details :mag_right:</summary>\n\n",
        "</details>\n\n",
        "\n</details>\n\n",
        0
    );
    my $footer_length = length $footer;
    if ($budget) {
        $budget -= (length $details_prefix) + (length $suffix);
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
            $need_suffix = 1;
        }
        print $header;
        print join ("", sort CheckSpelling::Util::case_biased @entries);
        print $footer;
        if ($budget) {
            $budget -= $cost;
            print STDERR "Summary Tables budget reduced to: $budget\n";
        }
    }
    print $suffix if $need_suffix;
}

1;
