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

use_ok("Parse::Selenese::TestCase");

my $case;

$case = Parse::Selenese::TestCase->new();

my $case_data_dir = "$FindBin::Bin/test_case_data";
my @selenese_data_files;
find sub { push @selenese_data_files, $File::Find::name if /_TestCase\.html$/ },
  $case_data_dir;

$case = Parse::Selenese::TestCase->new( $selenese_data_files[0] );

warn @{ $case->commands}[0]->as_html;

done_testing();
