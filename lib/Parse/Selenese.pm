# ABSTRACT: Parser for Selenese
use Modern::Perl;
use File::Basename;
use HTML::TreeBuilder;
use Carp ();

package Parse::Selenese;
use Moose;
use MooseX::FollowPBP;

has 'content' => ( isa => 'Str', is => 'rw', required => 0 );

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
