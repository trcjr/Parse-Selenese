use Algorithm::Diff;
use Cwd;
use Data::Dumper;
use File::Basename;
use File::Find qw(find);
use File::Spec;
use FindBin;
use Modern::Perl;
use Test::Exception;
use Test::Most;
use Test::Differences;
use YAML qw'freeze thaw LoadFile';

unified_diff;
my $case;

use_ok("Parse::Selenese");

#use_ok("Parse::Selenese::TestCase");

my $case_data_dir = "$FindBin::Bin/test_case_data";
my @selenese_data_files;
find sub { push @selenese_data_files, $File::Find::name if /_TestCase\.html$/ },
  $case_data_dir;

#
# Empty TestCase
#
dies_ok { Parse::Selenese::parse(); }
"dies trying to parse when given nothing to parse";

$case = Parse::Selenese::parse( $selenese_data_files[0] );
ok( ref($case) && eval { $case->isa('Parse::Selenese::TestCase') },
    "object is a Parse::Selenese::TestCase" );

$case = Parse::Selenese::TestCase->new();
ok !$case->filename, 'TestCase without filename has undefined filename';
ok !@{ $case->commands }, 'TestCase without commans commands 0 commands';
ok !$case->base_url, 'Unparsed TestCase has no base_url';
ok !$case->content,  'Unparsed TestCase has no content';

dies_ok { Parse::Selenese::TestCase->new('some_file'); }
'dies parsing a non existent file';
dies_ok { my $c = Parse::Selenese::TestCase->new(); $c->parse(); }
'dies trying to parse when given nothing to parse';

lives_ok {
my $c =
  Parse::Selenese::TestCase->new(  filename => $selenese_data_files[0]  );
}
$selenese_data_files[0] . " - Lives new with filename arg";

##
## TestCase from file
##
my $not_existing_file = "t/this_file_does_not_exist";
dies_ok {
    $case->filename($not_existing_file);
    $case->parse;
}
"$not_existing_file - dies trying to parse file that does not exist";

lives_ok {
    $case->filename( $selenese_data_files[0] );
    $case->parse;
}
$selenese_data_files[0] . " - Lives parsing a file";

foreach my $test_selenese_file (@selenese_data_files) {
    $test_selenese_file = File::Spec->abs2rel($test_selenese_file);
    my ( $file, $dir, $ext ) =
      File::Basename::fileparse( $test_selenese_file, qr/\.[^.]*/ );
    my $yaml_data_file = "$dir/$file.yaml";

    # Parse the html file
    $case = Parse::Selenese::parse($test_selenese_file);

    # Test against the original parsed file
    _test_selenese( $case, $test_selenese_file );

    # Test against the saved yaml
    #_test_yaml( $case, $yaml_data_file );

    # Test against the saved perl
    my $perl_data_file = "$dir/$file.pl";
    #_test_perl( $case, $perl_data_file );

}

sub _test_selenese {
    my $case               = shift;
    my $test_selenese_file = shift;

    open my $io, '<:encoding(utf8)', $test_selenese_file;
    my $content = join( '', <$io> );
    close $io;
    my $case2 = Parse::Selenese::parse($content);

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

            #my $perl_data = LoadFile($perl_data_file);
            # Read the saved perl code
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

done_testing();
