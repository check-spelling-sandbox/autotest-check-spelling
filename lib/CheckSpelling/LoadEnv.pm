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

sub read_config_from_file {
    my ($parsed_inputs) = @_;
    open my $config_data, '<:encoding(UTF-8)', get_json_config_path($parsed_inputs);
    return parse_config_file($config_data);
}

sub parse_inputs {
    my $input = $ENV{INPUTS};
    my %inputs;
    if ($input) {
        %inputs = %{decode_json(Encode::encode_utf8($input))};
    }

    my %input_map;
    for my $key (keys %inputs) {
        next unless $key;
        my $val = $inputs{$key};
        next unless $val ne '';
        my $var = $key;
        if ($val =~ /^github_pat_/) {
            print STDERR "Censoring `$var` (unexpected-input-value)\n";
            next;
        }
        next if $var =~ /\s/;
        next if $var =~ /[-_](?:key|token)$/;
        if ($var =~ /-/ && $inputs{$var} ne '') {
            my $var_pattern = $var;
            $var_pattern =~ s/-/[-_]/g;
            my @vars = grep { /^${var_pattern}$/ && ($var ne $_) && $inputs{$_} ne '' && $inputs{$var} ne $inputs{$_} } keys %inputs;
            print STDERR 'Found conflicting inputs for '.$var." ($inputs{$var}): ".join(', ', map { "$_ ($inputs{$_})" } @vars)." (migrate-underscores-to-dashes)\n" if (@vars);
            $var =~ s/-/_/g;
        }
        ($var, $val) = escape_var_val($var, $val);
        $input_map{$var} = $val;
    }

    my $parsed_inputs = {
        maybe_load_inputs_from => $maybe_load_inputs_from,
        input_map => \%input_map,
    };
    parse_action_config($parsed_inputs);
    return $parsed_inputs;
}

sub parse_action_config {
    my ($parsed_inputs) = @_;
    my $action_yml_path = $ENV{action_yml};
    return unless defined $action_yml_path;

    my $from_yaml = YAML::PP::LoadFile($action_yml_path);
    my $config_as_json = encode_json($from_yaml);
    open my $action_fh, '<', \$config_as_json;
    my %action = %{parse_config_file($action_fh)};
    return unless defined $action{inputs};
    my %input_map = %{$parsed_inputs->{'input_map'}};
    my %action_inputs = %{$action{inputs}};
    for my $key (sort keys %action_inputs) {
        my %ref = %{$action_inputs{$key}};
        next unless defined $ref{default};
        next if defined $input_map{$key};
        my $var = $key;
        next if $var =~ /[-_](?:key|token)$/i;
        if ($var =~ s/-/_/g) {
            next if defined $input_map{$var};
        }
        my $val = $ref{default};
        next if $val eq '';
        ($var, $val) = escape_var_val($var, $val);
        $input_map{$var} ||= $val;
    }
    $parsed_inputs->{'input_map'} = \%input_map;
}

sub get_json_config_path {
    my ($parsed_inputs) = @_;
    my $config = $parsed_inputs->{'input_map'}{'config'} || '.github/actions/spelling';
    return "$config/config.json";
}

sub read_project_config {
    my ($parsed_inputs) = @_;
    return read_config_from_file(get_json_config_path($parsed_inputs));
}

1;
