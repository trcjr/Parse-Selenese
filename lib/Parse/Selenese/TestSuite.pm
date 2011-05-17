# ABSTRACT: A Selenese Test Case
package Parse::Selenese::TestSuite;
use strict;
use warnings;
use Moose;
use Carp ();
use File::Basename;
use HTML::TreeBuilder;
use Parse::Selenese::TestCase;

has 'cases' =>
  ( isa => 'ArrayRef', is => 'rw', required => 0, default => sub { [] } );

# Return whether the specified file is a test suite or not
# static method
sub is_suite_file {
    my ($filename) = @_;

    die "Can' t read $filename " unless -r $filename;

    my $tree = HTML::TreeBuilder->new;
    $tree->parse_file($filename);

    my $table = $tree->look_down( 'id', 'suiteTable' );
    return !!$table;
}

# Bulk convert test cases in this suite
sub bulk_convert {
    my $self = shift;

    my @outfiles;
    foreach my $case ( @{ $self->cases } ) {
        push( @outfiles, $case->convert_to_perl );
    }
    return @outfiles;
}

# Return TestCase objects in the specified suite
sub get_cases {
    __PACKAGE__->new(shift)->cases;
}

# Return test case filenames in the specified suite
sub get_case_files {
    map { $_->{filename} } __PACKAGE__->new(shift)->cases;
}

sub new_o {
    my ( $class, $filename ) = @_;
    my $self = bless {
        filename => $filename,
        cases    => undef,
    }, $class;

    $self->parse if $filename;

    $self;
}

sub parse {
    my $self           = shift;
    my $suite_filename = $self->{filename};

    die " Can't read $suite_filename " unless -r $suite_filename;

    my $tree = HTML::TreeBuilder->new;
    $tree->parse_file($suite_filename);

    # base_urlを<link>から見つける
    my $base_url;
    foreach my $link ( $tree->find('link') ) {
        if ( $link->attr('rel') eq 'selenium.base' ) {
            $base_url = $link->attr('href');
        }
    }

    # <tbody>以下からコマンドを抽出
    my $tbody    = $tree->find('tbody');
    my $base_dir = File::Basename::dirname( $self->{filename} );
    my @cases;
    if ($tbody) {
        foreach my $tr ( $tbody->find('tr') ) {
            my $link = $tr->find('td')->find('a');
            if ($link) {
                my $case;
                eval {
                    $case = Parse::Selenese::TestCase->new(
                        $base_dir . '/' . $link->attr('href') );
                };
                if ($@) {
                    warn " Can't read test case $base_dir /
  " . $link->attr('href') . "
  : $! \n ";
                }
                push( @cases, $case ) if $case;
            }
        }
    }
    $tree = $tree->delete;

    $self->{cases} = \@cases;
}

1;
