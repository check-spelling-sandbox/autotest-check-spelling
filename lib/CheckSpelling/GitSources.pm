#! -*-perl-*-
package CheckSpelling::GitSources;

use Cwd 'abs_path';
use File::Basename;
use File::Temp qw/ tempfile tempdir /;
use JSON::PP;
use CheckSpelling::Util;

unless (eval 'use URI::Escape; 1') {
    eval 'use URI::Escape::XS qw/uri_escape/';
}

my %git_roots = ();
my %github_urls = ();
my $pull_base;
my $pull_head;

sub github_repo {
    my ($source) = @_;
    $source =~ s<https://[^/]+/|.*:><>;
    $source =~ s<\.git$><>;
    return '' unless $source =~ m#^[^/]+/[^/]+$#;
    return $source;
}

sub file_ref {
    my ($file, $line) = @_;
    $file =~ s/ /%20/g;
    return "$file:$line";
}

sub find_git {
    our $git_dir;
    return $git_dir if defined $git_dir;
    if ($ENV{PATH} =~ /(.*)/) {
        my $path = $1;
        for my $maybe_git (split /:/, $path) {
            if (-x "$maybe_git/git") {
                $git_dir = $maybe_git;
                return $git_dir;
            }
        }
    }
}

sub git_source_and_rev {
    my ($file) = @_;
    our (%git_roots, %github_urls, $pull_base, $pull_head);

    my $last_git_dir;
    my $dir = $file;
    my @children;
    while ($dir ne '.' && $dir ne '/') {
        my $child = basename($dir);
        push @children, $child;
        my $parent = dirname($dir);
        last if $dir eq $parent;
        $dir = $parent;
        last if defined $git_roots{$dir};
        my $git_dir = "$dir/.git";
        if (-e $git_dir) {
            if (-d $git_dir) {
                $git_roots{$dir} = $git_dir;
                last;
            }
            if (-s $git_dir) {
                open $git_dir_file, '<', $git_dir;
                my $git_dir_path = <$git_dir_file>;
                close $git_dir_file;
                if ($git_dir_path =~ /^gitdir: (.*)$/) {
                    $git_roots{$dir} = abs_path("$dir/$1");
                }
            }
        }
    }
    $last_git_dir = $git_roots{$dir};
    my $length = scalar @children - 1;
    for (my $i = 0; $i < $length; $i++) {
        $dir .= "/$children[$i]";
        $git_roots{$dir} = $last_git_dir;
    }

    return () unless defined $last_git_dir;
    $file = join '/', (reverse @children);

    my $prefix = '';
    if (defined $github_urls{$last_git_dir}) {
        $prefix = $github_urls{$last_git_dir};
    } else {
        my $full_path = $ENV{PATH};
        $ENV{PATH} = find_git();
        my $git_dir = $ENV{GIT_DIR};
        $ENV{GIT_DIR} = $last_git_dir;
        my $git_remotes = `git remote`;
        my @remotes = split /\n/, $git_remotes;
        my $origin;
        if (grep { /^origin$/ } @remotes) {
            $origin = 'origin';
        } elsif (@remotes) {
            $origin = $remotes[0];
        }
        my $remote_url;
        my $rev;
        if ($origin) {
            $remote_url = `git remote get-url "$origin" 2>/dev/null`;
            chomp $remote_url;
            $rev = `git rev-parse HEAD 2>/dev/null`;
            chomp $rev;
            my $private_synthetic_sha = $ENV{PRIVATE_SYNTHETIC_SHA};
            if (defined $private_synthetic_sha) {
                $rev = $ENV{PRIVATE_MERGE_SHA} if ($rev eq $private_synthetic_sha);
            }
        }
        $ENV{PATH} = $full_path;
        $ENV{GIT_DIR} = $git_dir;
        my $url_base;
        $remote_url = '' if $remote_url eq '.';
        if ($remote_url) {
            unless ($remote_url =~ m<^https?://>) {
                $remote_url =~ s!.*\@([^:]+):!https://$1/!;
            }
            $remote_url =~ s!\.git$!!;
            $url_base = "$remote_url/blame";
        } elsif ($ENV{GITHUB_SERVER_URL} ne '' && $ENV{GITHUB_REPOSITORY} ne '') {
            $url_base = "$ENV{GITHUB_SERVER_URL}/$ENV{GITHUB_REPOSITORY}/blame";
            $rev = $ENV{GITHUB_HEAD_REF} || $ENV{GITHUB_SHA} unless $rev;
        }
        if ($url_base) {
            if ($pull_base) {
                $url_base =~ s<^$pull_base/><$pull_head/>i;
            }
            $prefix = "$url_base/$rev/";
        }
        if ($last_git_dir) {
            $github_urls{$last_git_dir} = $prefix;
        }
    }
    return ($prefix, $file);
}

1;
