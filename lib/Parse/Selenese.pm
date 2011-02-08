# ABSTRACT: Parser for Selenese
package Parse::Selenese;
use strict;
use Modern::Perl;
use Moose;
use Parse::Selenese::TestCase;

sub parse_case {
    Parse::Selenese::TestCase->new(shift);
}


1;

__END__

=head1 NAME

Parse::Selenese -

=head1 SYNOPSIS

  use Parse::Selenese;

=head1 DESCRIPTION

WWW::Selenium::Selenese is

=head1 AUTHOR

Theodore Robert Campbell Jr.  E<lt>trcjr@cpan.orgE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
