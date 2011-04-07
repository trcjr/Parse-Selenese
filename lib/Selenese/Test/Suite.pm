# ABSTRACT: A Selenium Test Suite
package Selenese::Test::Suite;
use Moose;

use strict;
use Carp ();
use File::Basename;
use HTML::TreeBuilder;
use Selenese::Test::Case;


has ' cases ' =>
  ( isa => ' ArrayRef ', is => ' rw ', required => 0, default => sub { [] } );

# Return whether the specified file is a test suite or not
# static method
sub is_suite_file {
    my ($filename) = @_;

    die "Can' t read $filename " unless -r $filename;

    my $tree = HTML::TreeBuilder->new;
    $tree->parse_file($filename);

    my $table = $tree->look_down('id', 'suiteTable');
    return !! $table;
}

# Bulk convert test cases in this suite
sub bulk_convert {
    my $self = shift;

    my @outfiles;
    foreach my $case (@{ $self->cases }) {
        push(@outfiles, $case->convert_to_perl);
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
    my ($class, $filename) = @_;
    my $self = bless {
        filename => $filename,
        cases    => undef,
    }, $class;

    $self->parse if $filename;

    $self;
}

sub parse {
    my $self = shift;
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
    my $tbody = $tree->find('tbody');
    my $base_dir = File::Basename::dirname( $self->{filename} );
    my @cases;
    if ($tbody) {
        foreach my $tr ( $tbody->find('tr') ) {
            my $link = $tr->find('td')->find('a');
            if ($link) {
                my $case;
                eval {
                    $case = Selenese::Test::Case->new(
                        $base_dir . '/' . $link->attr('href')
                    );
                };
                if ($@) {
                    warn " Can't read test case $base_dir /
  ".$link->attr('href')."
  : $! \n ";
                }
                push(@cases, $case) if $case;
            }
        }
    }
    $tree = $tree->delete;

    $self->{cases} = \@cases;
}

1;
__END__

=head1 NAME

Selenese::Test::Suite

=head1 SYNOPSIS

    use Selenese::Test::Case;
    my $tc = Selenese::Test::Case->new;
    $tc->from_file($filename);
    $tc = Selenese::Test::Case->new->from_file($filename);
    $tc = Selenese::Test::Case->new->from_string($string);
    $tc = Selenese::Test::Case->new->from_commands(\@commands);



=head1 DESCRIPTION

Selenium::Test::Case can be used to turn a test case in Selenese HTML format 
into an object that usable by perl.

=head2 METHODS

=head3 C< parse >

Parse the filename or string into C< Selenium::Commands > for use by the
object.



=head3 C< short_name >

The short name of the test case

    print $tc->short_name;
    # load_some_page

=head3 C< as_html >

Return a scalar representing the command in HTML.


=head3 C< as_perl >

Return a scalar representing the command in perl.


=head3 C< save( [$filename]) >

Save the test case to optional filename.

=head1 AUTHOR

Theodore Robert Campbell Jr E<lt>trcjr@cpan.orgE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
