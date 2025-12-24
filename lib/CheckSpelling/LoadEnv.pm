#! -*-perl-*-

package CheckSpelling::LoadEnv;

use feature 'unicode_strings';
use Encode qw/decode_utf8 encode_utf8 FB_DEFAULT/;
use YAML::PP;
use JSON::PP;

sub print_var_val {
    my ($var, $val) = @_;
    if ($var =~ /[-a-z]/) {
        print STDERR "Found improperly folded key in inputs '$var'\n";
        return;
    }
    return if $val eq '';
    print qq<export INPUT_$var='$val';\n>;
}

sub escape_var_val {
    my ($var, $val) = @_;
    $val =~ s/([\$])/\\$1/g;
    $val =~ s/'/'"'"'/g;
    $var = uc $var;
    $var =~ s/-/_/g;
    return ($var, $val);
}

sub parse_config_file {
    my ($config_data) = @_;
    local $/ = undef;
    my $base_config_data = <$config_data>;
    close $config_data;
    return decode_json($base_config_data || '{}');
}

sub parse_inputs {
    my $input = $ENV{INPUTS};
    my %raw_inputs;
    if ($input) {
        %raw_inputs = %{decode_json(Encode::encode_utf8($input))};
    }

    my %inputs;
    for my $key (keys %raw_inputs) {
        next unless $key;
        my $val = $raw_inputs{$key};
        next unless $val ne '';
        my $var = $key;
        if ($val =~ /^github_pat_/) {
            print STDERR "Censoring `$var` (unexpected-input-value)\n";
            next;
        }
        next if $var =~ /\s/;
        next if $var =~ /[-_](?:key|token)$/;
        if ($var =~ /-/ && $raw_inputs{$var} ne '') {
            my $var_pattern = $var;
            $var_pattern =~ s/-/[-_]/g;
            my @vars = grep { /^${var_pattern}$/ && ($var ne $_) && $raw_inputs{$_} ne '' && $raw_inputs{$var} ne $raw_inputs{$_} } keys %raw_inputs;
            if (@vars) {
                print STDERR 'Found conflicting inputs for '.$var." ($raw_inputs{$var}): ".join(', ', map { "$_ ($raw_inputs{$_})" } @vars)." (migrate-underscores-to-dashes)\n";
            }
            $var =~ s/-/_/g;
        }
        ($var, $val) = escape_var_val($var, $val);
        $inputs{$var} = $val;
    }

    my $parsed_inputs = {
        maybe_load_inputs_from => $maybe_load_inputs_from,
        inputs => \%inputs,
    };
    parse_action_config($parsed_inputs);
    return $parsed_inputs;
}

sub parse_action_config {
    my ($parsed_inputs) = @_;
    my $action_yml_path = $ENV{action_yml};
    return unless defined $action_yml_path;

    my $action = YAML::PP::LoadFile($action_yml_path);
    return unless defined $action->{inputs};
    my %inputs = %{$parsed_inputs->{'inputs'}};
    my %action_inputs = %{$action->{inputs}};
    for my $key (sort keys %action_inputs) {
        my %ref = %{$action_inputs{$key}};
        next unless defined $ref{default};
        next if defined $inputs{$key};
        my $var = $key;
        next if $var =~ /[-_](?:key|token)$/i;
        if ($var =~ s/-/_/g) {
            next if defined $inputs{$var};
        }
        my $val = $ref{default};
        next if $val eq '';
        ($var, $val) = escape_var_val($var, $val);
        next if defined $inputs{$var};
        $inputs{$var} = $val;
    }
    $parsed_inputs->{'inputs'} = \%inputs;
}

sub get_json_config_path {
    my ($parsed_inputs) = @_;
    my $config = $parsed_inputs->{'inputs'}{'config'} || '.github/actions/spelling';
    return "$config/config.json";
}

1;
