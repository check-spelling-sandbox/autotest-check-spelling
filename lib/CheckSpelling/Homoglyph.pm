#! -*-perl-*-

package CheckSpelling::Homoglyph;

our $VERSION='0.1.0';
our $flatten=0;

use utf8;
use CheckSpelling::Util;

my %homoglyph_map;
my $homoglyphs;

my %homoglyph_to_glyph;

sub init {
    my ($file) = @_;
    return unless open (my $fh, '<:encoding(UTF-8)', $file);
    my $ignore_pattern = CheckSpelling::Util::get_file_from_env_utf8('INPUT_IGNORE_PATTERN', q<[^a-zA-Z']>);
    my $upper_pattern = CheckSpelling::Util::get_file_from_env_utf8('INPUT_UPPER_PATTERN', '[A-Z]');
    my $lower_pattern = CheckSpelling::Util::get_file_from_env_utf8('INPUT_LOWER_PATTERN', '[a-z]');
    my $not_lower_pattern = CheckSpelling::Util::get_file_from_env_utf8('INPUT_NOT_LOWER_PATTERN', '[^a-z]');
    my $not_upper_or_lower_pattern = CheckSpelling::Util::get_file_from_env_utf8('INPUT_NOT_UPPER_OR_LOWER_PATTERN', '[^A-Za-z]');
    my $punctuation_pattern = CheckSpelling::Util::get_file_from_env_utf8('INPUT_PUNCTUATION_PATTERN', q<'>);
    local $/ = "\n";
    while (<$fh>) {
        next if /^#/;
        s/^\\//;
        next unless /(.)(.+)/;
        my ($expected, $aliases) = ($1, $2);
        my @chars = split('', $aliases);
        next unless $expected =~ /$upper_pattern|$lower_pattern|$punctuation_pattern/;
        next unless $expected =~ /$upper_pattern|$lower_pattern/;
        my @unexpected_chars;
        for my $ch (@chars) {
            if ($ch =~ /$ignore_pattern/) {
                my %ref;
                my $known_aliases = \%ref;
                if (defined $homoglyph_map{$ch}) {
                    $known_aliases = $homoglyph_map{$ch};
                }
                $known_aliases->{$expected} = 1;
                $homoglyph_map{$ch} = $known_aliases;
            }
        }
    }
    close $fh;
    my @glyphs = sort keys %homoglyph_map;
    our $homoglyphs = join '', @glyphs;
    our %homoglyph_to_glyph;
    for my $ch (@glyphs) {
        my @known_aliases = keys %{$homoglyph_map{$ch}};
        if (scalar @known_aliases == 1) {
            $homoglyph_to_glyph{$ch} = $known_aliases[0];
        } else {
            $homoglyph_to_glyph{$ch} = $ch;
        }
    }
}

sub dump_aliases {
    my $a;
    for my $ch (keys %homoglyph_map) {
        $a = $ch;
        my $b = $homoglyph_map{$a};
        print "$a: ".(join " ", (sort keys %$b))."\n";
    }
    print "\n"."homoglyphs: $homoglyphs\n";
}
1;
