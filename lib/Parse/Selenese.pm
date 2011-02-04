# ABSTRACT: Parser for Selenese
use Encode;
use Modern::Perl;
use File::Basename;
use HTML::TreeBuilder;
use Carp ();

package Parse::Selenese;
use Moose::Role;

has 'content' => ( isa => 'Str', is => 'rw', required => 0 );
has 'filename' => ( isa => 'Str', is => 'rw', required => 0 );
has 'path' => ( isa => 'Str', is => 'rw', required => 0 );
has 'base_url' => ( isa => 'Str', is => 'rw', required => 0 );
has 'title' => ( isa => 'Str', is => 'rw', required => 0 );
has 'thead' => ( isa => 'Str', is => 'rw', required => 0 );

requires 'parse';

sub BUILD {
    my $self = shift;
    $self->parse if defined $self->filename || defined $self->content;
}

sub _parse {
    my $self = shift;

    if ( defined ($self->content) && defined ($self->filename) ){
        unless (-r $self->filename) {
            die "file isn't readable";
        }
    } else {
        die "file isn't defined";
    }

    return if scalar @{$self->commands};

    my $tree = HTML::TreeBuilder->new;
    $tree->store_comments(1);

    #if ( $self->filename ) {
    #    $tree->parse_file( $self->filename );
    #} elsif ( $self->content ) {
    #    $tree->parse_content( $content );
    #}
    #$tree->parse;

    # base_urlを<link>から見つける
    foreach my $link ( $tree->find('link') ) {
        if ( $link->attr('rel') eq 'selenium.base' ) {
            $self->base_url( $link->attr('href') );
        }
    }

    # title
    $self->title($self->_parse_title($tree));

    # table head
    $self->thead($self->_parse_thead($tree));

    return $tree;
}

sub _parse_thead {
    my $self = shift;
    my $tree = shift;
    if ( $tree->find('thead') ) {
        if ( $tree->find('thead')->find( 'td', rowspan => 3 ) ) {
            return $tree->find('thead')->find( 'td', rowspan => 3 )
              ->content->[0];
        }
    }
    return '';
}

sub _parse_title {
    my $self = shift;
    my $tree = shift;
    return $tree->find('title') ? $tree->find('title')->content->[0] : '';
    #return $tree->find('title')->content->[0] if $tree->find('title');
}

sub parse_content {
    my $self    = shift;
    my $content = shift;
    $self->content( Encode::decode_utf8 $content );
    $self->_parse;
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
