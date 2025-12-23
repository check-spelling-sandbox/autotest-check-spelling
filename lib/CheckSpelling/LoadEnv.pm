#! -*-perl-*-

package CheckSpelling::LoadEnv;

use feature 'unicode_strings';
use Encode qw/decode_utf8 encode_utf8 FB_DEFAULT/;
use JSON::PP;

sub print_var_val {
    my ($var, $val) = @_;
    $var = 'INPUT_'.(uc $var);
    print qq<export $var='$val';\n>;
}

sub expect_array {
    my ($ref, $label) = @_;
    my $ref_kind = ref $ref;
    if ($ref eq '') {
        $ref = [];
    } elsif (ref $ref ne 'ARRAY') {
        print STDERR "'$label' should be an array (unsupported-configuration)\n";
        $ref = [];
    }
    return $ref;
}

sub expect_map {
    my ($ref, $label) = @_;
    my $ref_kind = ref $ref;
    if ($ref eq '') {
        $ref = {};
    } elsif (ref $ref ne 'HASH') {
        print STDERR "'$label' should be a map (unsupported-configuration)\n";
        $ref = {};
    }
    return $ref;
}

sub array_to_map {
    my ($array_ref) = @_;
    return map { $_ => 1 } @$array_ref;
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

sub read_config_from_sha {
    my ($github_head_sha, $json_config_path) = @_;
    open (my $config_data, '-|:encoding(UTF-8)', qq<git show '$github_head_sha':'$json_config_path' || echo '{"broken":1}'>);
    return parse_config_file($config_data);
}

sub read_config_from_file {
    my ($json_config_path) = @_;
    open my $config_data, '<:encoding(UTF-8)', $json_config_path;
    return parse_config_file($config_data);
}

sub parse_inputs {
    my ($load_config_from_key) = @_;
    my $input = $ENV{INPUTS};
    my %inputs;
    if ($input) {
        %inputs = %{decode_json(Encode::encode_utf8($input))};
    }
    my $maybe_load_inputs_from = $inputs{$load_config_from_key};
    delete $inputs{$load_config_from_key};

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

    my $config = $input_map{'config'} || '.github/actions/spelling';
    my $json_config_path = "$config/config.json";

    return {
        maybe_load_inputs_from => $maybe_load_inputs_from,
        load_config_from_key => $load_config_from_key,
        input_map => \%input_map,
        json_config_path => $json_config_path,
    };
}

sub parse_action_config {
    my ($input_map_ref) = @_;
    my %input_map = %{$input_map_ref};
    my $action_json_path = $ENV{action_yml_json};
    my %action = read_config_from_file($action_json_path);
    return unless defined $action{inputs};
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
        $val =~ s/([\$])/\\$1/g;
        $val =~ s/'/'"'"'/g;
        $var = 'INPUT_'.(uc $var);
        next if defined $ENV{$var};
        print_var_val($var, $val);
    }
}

sub get_supported_key_list {
    my @supported_key_list = qw(
        check_file_names
        dictionary_source_prefixes
        dictionary_url
        dictionary_version
        extra_dictionaries
        extra_dictionary_limit
        errors
        notices
        longest_word
        lower-pattern
        punctuation-pattern
        upper-pattern
        ignore-pattern
        lower-pattern
        not-lower-pattern
        not-upper-or-lower-pattern
        punctuation-pattern
        upper-pattern
        warnings
    );
    return \@supported_key_list;
}

sub read_project_config {
    my ($parsed_inputs) = @_;
    my $json_config_path = $parsed_inputs->{'json_config_path'};
    return read_config_from_file($json_config_path);
}

sub load_untrusted_config {
    my ($parsed_inputs, $event_name) = @_;
    my %input_map = %{$parsed_inputs->{'input_map'}};
    my $maybe_load_inputs_from = $parsed_inputs->{'maybe_load_inputs_from'};
    my $load_config_from_key = $parsed_inputs->{'load_config_from_key'};

    my %supported_keys = array_to_map(get_supported_key_list);

    if (defined $maybe_load_inputs_from) {
        $maybe_load_inputs_from = expect_map($maybe_load_inputs_from, $load_config_from_key);
        my %load_config_from = %$maybe_load_inputs_from;
        my $use_repo_config_keys = 'use-repo-config-keys';
        my $trust_attacker_keys = 'trust-attacker-keys';
        my $use_repo_config_key = expect_array($load_config_from{$use_repo_config_keys}, "$load_config_from_key->$use_repo_config_keys");
        my $trust_attacker_key = expect_array($load_config_from{$trust_attacker_keys}, "$load_config_from_key->$use_repo_config_keys");
        my @use_repo_config_key_list = @$use_repo_config_key;
        my @trust_attacker_key_list = @$trust_attacker_key;
        my %use_repo_config_key_map = array_to_map $use_repo_config_key if (defined $use_repo_config_key);
        my %trust_attacker_key_map = array_to_map $trust_attacker_key if (defined $trust_attacker_key);
        for my $key (keys %trust_attacker_key_map) {
            if (defined $use_repo_config_key_map{$key}) {
                delete $trust_attacker_key_map{$key};
                print STDERR "'$key' found in both $use_repo_config_keys and $trust_attacker_keys of $load_config_from_key (unsupported-configuration)\n";
            }
            unless (defined $supported_keys{$key}) {
                delete $trust_attacker_key_map{$key};
                print STDERR "'$key' cannot be set in $trust_attacker_keys of $load_config_from_key (unsupported-configuration)\n";
            }
        }
        if (%use_repo_config_key_map) {
            print STDERR "need to read base file\n";
        }
        my $experimental_path = $input_map{'experimental_path'} || '.';

        my $github_head_sha;
        open my $github_event_file, '<:encoding(UTF-8)', $ENV{GITHUB_EVENT_PATH};
        {
            local $/ = undef;
            my $github_event_data = <$github_event_file>;
            close $github_event_file;
            my $github_event = decode_json $github_event_data;
            $github_head_sha = $github_event->{'pull_request'}->{'base'}->{'sha'} if ($github_event->{'pull_request'} && $github_event->{'pull_request'}->{'base'});
        }

        if (%trust_attacker_key_map) {
            my ($maybe_dangerous, $local_config);
            if (defined $event_name && $event_name eq 'pull_request_target') {
                ($maybe_dangerous, $local_config) = (' (dangerous)', 'attacker');
            } else {
                ($maybe_dangerous, $local_config) = ('', 'local');
            }

            print STDERR "will read live file$maybe_dangerous\n";
            my %dangerous_config = %{read_project_config($parsed_inputs)};
            for my $key (sort keys %dangerous_config) {
                if (defined $trust_attacker_key_map{$key}) {
                    my $val = $dangerous_config{$key};
                    ($key, $val) = escape_var_val($key, $val);
                    print STDERR "Trusting '$key': $val\n";
                    $input_map{$key} = $val;
                } else {
                    print STDERR "Ignoring '$key' from $local_config config\n";
                }
            }

            my $json_config_path = $parsed_inputs->{'json_config_path'};
            my %base_config = %{read_config_from_sha($github_head_sha, $json_config_path)};
            for my $key (sort keys %base_config) {
                if (defined $use_repo_config_key_map{$key}) {
                    my ($var, $val);
                    ($var, $val) = escape_var_val($key, $base_config{$key});
                    print STDERR "Using '$key': $val\n";
                    $input_map{$var} = $val;
                } else {
                    print STDERR "Ignoring '$key' from base config\n";
                }
            }
        }
    }
    $parsed_inputs->{'input_map'} = \%input_map;
}

sub load_trusted_config {
    my ($parsed_inputs) = @_;
    my %project_config = %{read_project_config($parsed_inputs)};
    my %input_map = %{$parsed_inputs->{'input_map'}};
    for my $key (keys %project_config) {
        my ($var, $val) = escape_var_val($key, $project_config{$key});
        $input_map{$var} = $val;
    }
    $parsed_inputs->{'input_map'} = \%input_map;
}

1;
