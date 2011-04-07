# ABSTRACT: Parser for Selenese
package Selenese;
use strict;
use Modern::Perl;
use Moose;
use Selenese::TestCase;

1;

__END__

=head1 NAME

Parse::Selenese -

=head1 SYNOPSIS

  use Parse::Selenese;

=head1 DESCRIPTION

WWW::Selenium::Selenese is

=head2 Functions

=over

=item C<Parse::Selenese::parse($filename|$content|%args)>

Return a Parse::Selenese::TestCase, Parse::Selenese::TestSuite or undef if
unable to parse the filename or content.

=back


=head1 AUTHOR

Theodore Robert Campbell Jr.  E<lt>trcjr@cpan.orgE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
