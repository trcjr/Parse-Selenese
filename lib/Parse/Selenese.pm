# ABSTRACT: Parser for Selenese
package Parse::Selenese;
use Moose;
use Parse::Selenese::TestCase;

# VERSION

sub parse {
    Parse::Selenese::TestCase->new(shift);
}

1;

__END__

=head1 NAME

Parse::Selenese - Easy Selenium Test Suite and Test Case parsing.

=head1 SYNOPSIS

  use Parse::Selenese;

=head1 DESCRIPTION

Parse::Selenese makes it easy to parse Selenium Test Suites and Test Cases from
their HTML format into Perl.

=head2 Functions

=over

=item C<Parse::Selenese::parse($file_name|$content|%args)>

Return a Parse::Selenese::TestCase, Parse::Selenese::TestSuite or undef if
unable to parse the file name or content.

=back


=head1 AUTHOR

Theodore Robert Campbell Jr.  E<lt>trcjr@cpan.orgE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
