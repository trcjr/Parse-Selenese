use Modern::Perl;

use File::Basename;
use YAML qw'freeze thaw LoadFile';

#use Test::More tests => 3;
use File::Find qw(find);
use File::Spec;
use Test::Most;
use Test::Exception;
use Data::Dumper;
use FindBin;
use Cwd;

#use Test::Base;
#use String::Diff;
use Algorithm::Diff;

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
dies_ok { Parse::Selenese::TestCase->new("some_file"); } "dies parsing a non existent file";
dies_ok { my $c = Parse::Selenese::TestCase->new(); $c->parse(); } "dies trying to parse when given nothing to parse";
#s_ok { my $c = Parse::Selenese::TestCase->new(); $c->parse(); } "dies trying to parse when given nothing to parse";

##
## TestCase from file
##

my $case_data_dir = "$FindBin::Bin/test_case_data";
my @selenese_data_files;
find sub { push @selenese_data_files, $File::Find::name if /_TestCase\.html$/ },
  $case_data_dir;

$case = Parse::Selenese::TestCase->new();

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

lives_ok {
    $case->parse;
}
"parse again!";

#done_testing();
foreach my $test_selenese_file (@selenese_data_files) {
    $test_selenese_file = File::Spec->abs2rel($test_selenese_file);
    my ( $file, $dir, $ext ) =
      File::Basename::fileparse( $test_selenese_file, qr/\.[^.]*/ );
    my $yaml_data_file = "$dir/$file.yaml";

    # Parse the html file
    $case = Parse::Selenese::TestCase->new($test_selenese_file);
    $case->parse;

    # Read the saved perl code
    open my $io, '<', $test_selenese_file or die $!;
    my $content = join( '', <$io> );
    close $io;

    #is( $case->as_html, $content, $case->filename . ' - selenese output precisely' );

    #unified_diff;
    #eq_or_diff $case->as_html, $content , $case->filename . ' - selenese output precisely' ;

    my $case2 = Parse::Selenese::TestCase->new();
    $case2->parse_content($content);
    #$case2->parse_content($content);
    $case->parse();

    # Test against the original parsed file
    _test_selenese ( $case ) ;

    # Test against the saved yaml
    _test_yaml( $case, $yaml_data_file ) if -e $yaml_data_file;

    # Test against the saved perl
    my $perl_data_file = "$dir/$file.pl";
    _test_perl( $case, $perl_data_file ) if -e $perl_data_file;

}
sub _test_selenese {
    my $case = shift;
    for my $command (@{$case->commands}) {
        is scalar @{ $command->values } => 3, "Three values in command";
    }
}

sub _test_perl {
    my $case           = shift;
    my $perl_data_file = shift;

    # Read the saved perl code
    open my $io, '<', $perl_data_file or die $!;
    my $expected = join( '', <$io> );
    close $io;

    is( $case->as_perl, $expected, $case->filename . ' - output precisely' );

    #    use Data::Dumper;
    #    warn Dumper Algorithm::Diff::diff(
    #      map [split "\n" => $_], $case->as_perl, $expected
    #    );
}

sub _test_yaml {
    my $case           = shift;
    my $yaml_data_file = shift;

    # Load the yaml dump that matches
    my $yaml_data = LoadFile($yaml_data_file);
    is $case->short_name => $yaml_data->{short_name}, $case->filename . " test case short name";

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
