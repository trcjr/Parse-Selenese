use Modern::Perl;

use File::Basename;
use YAML qw'freeze thaw LoadFile';

#use Test::More tests => 3;
use File::Find qw(find);
use File::Spec;
use Test::More;
use Data::Dumper;
use FindBin;
use Cwd;

#use Test::Base;
#use String::Diff;
#use Algorithm::Diff;

use_ok("Parse::Selenese");
use_ok("Parse::Selenese::TestCase");

my $case;

#
# Empty TestCase
#
$case = Parse::Selenese::TestCase->new();

is( $case->get_filename, undef,
    "TestCase without filename has undefined filename" );
is( scalar( @{ $case->get_commands } ),
    0, "TestCase without commans commands 0 commands" );
is( $case->get_base_url, undef, "Unparsed TestCase has no base_url" );
is( $case->get_content,  undef, "Unparsed TestCase has no content" );

##
## TestCase from file
##

#is( $case->short_name, "hello_world_test_case", "test case short name" );

my $case_data_dir = "$FindBin::Bin/test_case_data";
my @yaml_data_files;
find sub { push @yaml_data_files, $File::Find::name if /_TestCase\.html$/ },
  $case_data_dir;

foreach my $test_selenese_file (@yaml_data_files) {
    $test_selenese_file = File::Spec->abs2rel($test_selenese_file);
    my ( $file, $dir, $ext ) =
      File::Basename::fileparse( $test_selenese_file, qr/\.[^.]*/ );
    my $yaml_data_file = "$dir/$file.yaml";
    next unless -e $yaml_data_file;

    # Parse the html file
    $case = Parse::Selenese::TestCase->new($test_selenese_file);

    # Load the yaml dump that matches
    my $yaml_data = LoadFile($yaml_data_file);

    is $case->get_filename => $yaml_data->{filename}, $case->get_file;

    is(
        $case->get_filename,
        $yaml_data->{filename},
        $case->get_filename . " filename"
    );

    is(
        $case->get_base_url,
        $yaml_data->{base_url},
        $case->get_filename . " base_url"
    );

    is(
        scalar @{ $case->get_commands },
        scalar @{ $yaml_data->{commands} },
        $case->get_filename . " number of commands in"
    );

    foreach my $command_index ( 0 .. scalar @{ $case->get_commands } - 1 ) {
        my $command        = @{ $case->get_commands }[$command_index];
        my $command_values = $command->{values};
        my $yaml_command_values =
          $yaml_data->{commands}[$command_index]->{values};
        foreach my $i ( 0 .. scalar @{$command_values} - 1 ) {
            my $command_value      = @{$command_values}[$i];
            my $yaml_command_value = @{$yaml_command_values}[$i];
            my $_test_name =
                $case->get_filename
              . " command num "
              . $command_index
              . " value $i";
            is( $command_value, $yaml_command_value, $_test_name );
        }
    }

    my $perl_data_file = "$dir/$file.pl";
    next unless -e $perl_data_file;

    open my $io, '<', $perl_data_file or die $!;
    my $expected = join( '', <$io> );
    close $io;
    is( $case->as_perl, $expected,
        'output precisely - ' . $case->get_filename );
}

done_testing();
