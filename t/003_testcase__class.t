use File::Find qw(find);
use FindBin;
use Data::Dumper;

use Test::Class::Most;

use Parse::Selenese;
use Parse::Selenese::TestCase;

use Test::Class::Most attributes => [qw/ empty_test_case selenese_data_files /];

INIT { Test::Class->runtests }

#__PACKAGE__->runtests;

sub startup : Tests(startup) {
    my $self = shift;
    $self->selenese_data_files(

        #$self->{_selenese_data_files} // sub {
        sub {
            warn "toast";
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
    $self->empty_test_case( Parse::Selenese::TestCase->new() );

}

sub teardown : Tests(teardown) {
}

sub shutdown : Tests(shutdown) {
}

sub object_default_values : Tests {
    my $self = shift;
    my $case = $self->empty_test_case;

    ok !$case->filename, 'TestCase without filename has undefined filename';
    ok !@{ $case->commands }, 'TestCase without commans commands 0 commands';
    ok !$case->base_url, 'Unparsed TestCase has no base_url';
    ok !$case->content,  'Unparsed TestCase has no content';

}

sub tests_that_should_die : Tests {
    my $self = shift;
    my $case = $self->empty_test_case();

    dies_ok { Parse::Selenese::TestCase->new('some_file'); }
    'dies parsing a non existent file';

    dies_ok {
        my $c = Parse::Selenese::TestCase->new();
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
          Parse::Selenese::TestCase->new(
            filename => $self->selenese_data_files->[0] );
    }
    $self->selenese_data_files->[0] . " - Lives new with filename arg";
}

1;
