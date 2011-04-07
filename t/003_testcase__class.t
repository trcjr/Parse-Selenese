use Algorithm::Diff;
use Cwd;
use Data::Dumper;
use Data::Dumper;
use File::Basename;
use File::Find qw(find);
use FindBin;
use Modern::Perl;
use Test::Differences;
use YAML qw'freeze thaw LoadFile';
use Selenese::Test::Case;

unified_diff;
use Test::Class::Most attributes => [qw/ empty_test_case selenese_data_files /];


INIT { Test::Class->runtests }

sub startup : Tests(startup) {
    my $self = shift;
    $self->selenese_data_files(

        #$self->{_selenese_data_files} // sub {
        sub {
            my $case_data_dir = "$FindBin::Bin/test_case_data";
            my @selenese_data_files;
            find sub {
                push @selenese_data_files, $File::Find::name
                  if /_TestCase\.html$/;
            }, $case_data_dir;
            $self->{_selenese_data_files} = \@selenese_data_files;
          }
          ->()
    );
}

sub setup : Tests(setup) {
    my $self = shift;
    $self->empty_test_case( Selenese::Test::Case->new() );

}

sub teardown : Tests(teardown) {
}

sub shutdown : Tests(shutdown) {
}

sub constructor : Tests {
    my $self = shift;
    my $case = new_ok("Selenese::Test::Case");

    ok !$case->filename, 'TestCase without filename has undefined filename';
    ok !@{ $case->commands }, 'TestCase without commans commands 0 commands';
    ok !$case->base_url, 'Unparsed TestCase has no base_url';
    ok !$case->content,  'Unparsed TestCase has no content';

}

sub tests_that_should_die : Tests {
    my $self = shift;
    my $case = $self->empty_test_case();

    #dies_ok { Parse::Selenese::parse(); }
    #"dies trying to parse when given nothing to parse";

    dies_ok { Selenese::Test::Case->new('some_file'); }
    'dies parsing a non existent file';

    dies_ok {
        my $c = Selenese::Test::Case->new();
        $c->parse();
    }
    'dies trying to parse when given nothing to parse';

    my $not_existing_file = "t/this_file_does_not_exist";
    dies_ok {
        $case->filename($not_existing_file);
        $case->parse;
    }
    "dies trying to parse file that does not exist - $not_existing_file";
}

sub tests_that_should_live : Tests {
    my $self = shift;
    my $case = $self->empty_test_case();

    lives_ok {
        my $c =
          Selenese::Test::Case->new(
            filename => $self->selenese_data_files->[0] );
    }
    $self->selenese_data_files->[0] . " - Lives new with filename arg";

    lives_ok {
        $case->filename( $self->selenese_data_files->[0] );
        $case->parse;
    }
    $self->selenese_data_files->[0] . " - Lives parsing a file";
}

sub test_each_stored_selenese_file : Tests {
    my $self = shift;
    my $case = $self->empty_test_case();

    foreach my $test_selenese_file ( @{ $self->selenese_data_files } ) {
        $test_selenese_file = File::Spec->abs2rel($test_selenese_file);
        my ( $file, $dir, $ext ) =
          File::Basename::fileparse( $test_selenese_file, qr/\.[^.]*/ );
        my $yaml_data_file = "$dir/$file.yaml";

        # Parse the html file
        $case = Selenese::Test::Case->new( filename => $test_selenese_file );
        #$case = Parse::Selenese::parse($test_selenese_file);

        # Test against the original parsed file
        _test_selenese( $case, $test_selenese_file );

        # Test against the saved yaml
        _test_yaml( $case, $yaml_data_file );

        # Test against the saved perl
        my $perl_data_file = "$dir/$file.pl";

        _test_perl( $case, $perl_data_file );

    }
}

sub _test_selenese {
    my $case               = shift;
    my $test_selenese_file = shift;

    open my $io, '<:encoding(utf8)', $test_selenese_file;
    my $content = join( '', <$io> );
    close $io;
    my $case2 = Selenese::Test::Case->new($content);

    eq_or_diff $content, $case->as_html,
      $case->filename . ' - selenese output precisely';
    eq_or_diff $case->as_html, $case2->as_html,
      $case->filename . ' - as_html reparsed still is the same';
}

sub _test_perl {
    my $case           = shift;
    my $perl_data_file = shift;

    my $test_count = 0;
    for my $idx ( 0 .. @{ $case->commands } - 1 ) {
        my $command        = $case->commands->[$idx];
        my $command_values = $command->{values};
        $test_count++ for 0 .. @$command_values - 1;
    }

  SKIP: {
        eval {
            open my $io, '<', $perl_data_file
              or die "Can't open perl data file";
            my $expected = join( '', <$io> );
            close $io;
        };
        if ($@) {
            skip "perl_data_file not found", $test_count;
        }
        open my $io, '<', $perl_data_file;
        my $expected = join( '', <$io> );
        close $io;

        unified_diff;
        eq_or_diff $expected, $case->as_perl,
          $case->filename . ' - selenese output precisely';

        #    use Data::Dumper;
        #    warn Dumper Algorithm::Diff::diff(
        #      map [split "\n" => $_], $case->as_perl, $expected
        #    );
    }
}

sub _test_yaml {
    my $case           = shift;
    my $yaml_data_file = shift;
    my $test_count     = 0;
    for my $idx ( 0 .. @{ $case->commands } - 1 ) {
        my $command        = $case->commands->[$idx];
        my $command_values = $command->{values};
        $test_count++ for 0 .. @$command_values - 1;
    }

  SKIP: {
        eval { my $yaml_data = LoadFile($yaml_data_file); };
        if ($@) {
            skip "$yaml_data_file not found", $test_count;
        }
        my $yaml_data = LoadFile($yaml_data_file);

        # Load the yaml dump that matches
        is $case->short_name => $yaml_data->{short_name},
          $case->filename . " test case short name";

        is $case->filename => $yaml_data->{filename},
          $case->filename . " filename";
        is $case->base_url => $yaml_data->{base_url},
          $case->filename . " base_url";

        is scalar @{ $case->commands } => scalar @{ $yaml_data->{commands} },
          $case->filename . " number of commands in";

        for my $idx ( 0 .. @{ $case->commands } - 1 ) {
            my $command             = $case->commands->[$idx];
            my $command_values      = $command->{values};
            my $yaml_command_values = $yaml_data->{commands}->[$idx]->{values};

            is $command_values->[$_] => $yaml_command_values->[$_],
              $case->filename
              . " command num $idx value $_ - $command_values->[$_]"
              for 0 .. @$command_values - 1;
        }
    }
}

1;
