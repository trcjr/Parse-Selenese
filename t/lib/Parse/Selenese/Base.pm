package Parse::Selenese::Base;
use strict;
use warnings;
use Algorithm::Diff;
use Cwd;
use Data::Dumper;
use File::Basename;
use File::Find qw(find);
use FindBin;
use Modern::Perl;
use Test::Differences;
use YAML qw'freeze thaw LoadFile';


use Test::Class::Most attributes => [qw/ empty_test_case selenese_data_files /];

sub startup : Tests(startup) {
    my $self = shift;
    $self->selenese_data_files(
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
}

sub teardown : Tests(teardown) {
}

sub shutdown : Tests(shutdown) {
}

1;
