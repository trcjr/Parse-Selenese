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

ok !$case->filename, 'TestCase without filename has undefined filename';
ok !@{ $case->commands }, 'TestCase without commans commands 0 commands';
ok !$case->base_url, "Unparsed TestCase has no base_url";
ok !$case->content,  "Unparsed TestCase has no content";

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

    # Parse the html file
    $case = Parse::Selenese::TestCase->new($test_selenese_file);

    # Test against the saved yaml
    _test_yaml( $case, $yaml_data_file ) if -e $yaml_data_file;

    # Test against the saved perl
    my $perl_data_file = "$dir/$file.pl";
    _test_perl( $case, $perl_data_file ) if -e $perl_data_file;

}

sub _test_perl {
    my $case           = shift;
    my $perl_data_file = shift;

    # Read the saved perl code
    open my $io, '<', $perl_data_file or die $!;
    my $expected = join( '', <$io> );
    close $io;

    is( $case->as_perl, $expected, 'output precisely - ' . $case->filename );
}

sub _test_yaml {
    my $case           = shift;
    my $yaml_data_file = shift;

    # Load the yaml dump that matches
    my $yaml_data = LoadFile($yaml_data_file);

    is $case->filename => $yaml_data->{filename}, $case->filename . " filename";
    is $case->base_url => $yaml_data->{base_url}, $case->filename . " base_url";

    is scalar @{ $case->commands } => scalar @{ $yaml_data->{commands} },
      $case->filename . " number of commands in";

    for my $idx ( 0 .. @{ $case->commands } - 1 ) {
        my $command             = $case->commands->[$idx];
        my $command_values      = $command->{values};
        my $yaml_command_values = $yaml_data->{commands}->[$idx]->{values};

        is $command_values->[$_] => $yaml_command_values->[$_],
          $case->filename . " command num $idx value $_ - $command_values->[$_]"
          for 0 .. @$command_values - 1;
    }
}

done_testing();
