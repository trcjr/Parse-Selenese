package Parse::Selenese::TestCase;
use strict;
use warnings;
use Moose;
use Carp ();
use Cwd;
use Encode;
use File::Basename;
use HTML::TreeBuilder;
use Parse::Selenese::Command;
use Parse::Selenese::TestCase;
use Text::MicroTemplate;
use Template;
use File::Temp;

use HTML::Element;

#use overload ('""' => 'as_html');


my ( $_test_mt, $_selenese_testcase_template, $_selenese_testcase_template2 );

has 'commands' =>
  ( isa => 'ArrayRef', is => 'rw', required => 0, default => sub { [] } );
has 'content'  => ( isa => 'Str', is => 'rw', required => 0 );
has 'filename' => ( isa => 'Str', is => 'rw', required => 0 );
has 'path'     => ( isa => 'Str', is => 'rw', required => 0 );
has 'base_url' => ( isa => 'Str', is => 'rw', required => 0 );
has 'title'    => ( isa => 'Str', is => 'rw', required => 0 );
has 'thead'    => ( isa => 'Str', is => 'rw', required => 0 );

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    if ( @_ == 1 && !ref $_[0] ) {
        return $class->$orig( filename => $_[0], )
          if defined $_[0]
              && defined Cwd::abs_path( $_[0] )
              && -e Cwd::abs_path( $_[0] );
        return $class->$orig( content => $_[0], );
    }
    elsif ( @_ == 1 && ref $_[0] ) {
        return $class->$orig( commands => $_[0], );
    }
    else {
        return $class->$orig(@_);
    }
};

sub BUILD {
    my $self = shift;
    $self->parse if defined $self->filename || defined $self->content;
}

sub short_name {
    my $self = shift;
    my $x    = File::Basename::basename( $self->filename );
    return ( File::Basename::fileparse( $x, qr/\.[^.]*/ ) )[0];
}

sub _parse_thead {
    my $self = shift;
    my $tree = shift;
    my $content = '';
    if ( $tree->find('thead') ) {
        if ( $tree->find('thead')->find( 'td', rowspan => 3 ) ) {
            $content = $tree->find('thead')->find( 'td', rowspan => 3 )
              ->content->[0];
        }
    }
    return $content;
}

sub _parse_title {
    my $self = shift;
    my $tree = shift;
    return
      defined $tree->find('title') ? $tree->find('title')->content->[0] : '';
}

sub parse {
    my $self = shift;


    # Only parse things once
    return if scalar @{ $self->commands };

    my $tree = HTML::TreeBuilder->new;
    $tree->store_comments(1);

    # Dear God this shouldn't be written like this. There _MUST_ be a better
    # way...
    # HOW DO I WROTE PERL?
    #    if ( defined( $self->filename ) || !defined( $self->content ) ) {
    #        unless ( defined ($self->filename) && (-r $self->filename) ) {
    #            die "file isn't readable";
    #        }
    #    }
    #    else {
    #        die "file isn't defined";
    #    }
    if ( defined( $self->filename ) ) {
        if ( !-r $self->filename ) {
            die "Um, I can't read the file you gave me to parse!";
        }
        $tree->parse_file( $self->filename );
    }
    elsif ( $self->content ) {
        my $x = $tree->parse_content(Encode::decode_utf8 $self->content );
        if ( !$x->find('title') ) {
            die
"OH GOD THAT THE CONTENT YOU GAVE ME ISN'T EVEN CLOSE TO A TEST CASE!!!";
        }
    }
    elsif ( !defined( $self->content ) || !defined( $self->filename ) ) {
        die "GIVE ME SOMETHING TO PARSE!";
    }
    else {
        warn "OH MY GOSH!";
    }

    foreach my $link ( $tree->find('link') ) {
        if ( $link->attr('rel') eq 'selenium.base' ) {
            $self->base_url( $link->attr('href') );
        }
    }

    # title
    $self->title( $self->_parse_title($tree) );

    # table head
    $self->thead( $self->_parse_thead($tree) );

    return unless my $tbody = $tree->find('tbody');
    my @commands;
    foreach my $trs_comments ( $tbody->find( ( 'tr', '~comment' ) ) ) {
        my @values;
        if ( $trs_comments->tag() eq '~comment' ) {
            @values = ( 'comment', $trs_comments->attr('text'), '' );
        }
        elsif ( $trs_comments->tag() eq 'tr' ) {

            @values = map {
                my $value = '';
                foreach my $child ( $_->content_list ) {

                    # <br />が含まれる場合はタグごと抽出
                    if ( ref($child) && eval { $child->isa('HTML::Element') } )
                    {
                        $value .= $child->as_HTML('<>&');
                    }
                    elsif ( eval { $child->can('attr') }
                        && $child->attr('_tag') == '~comment' )
                    {
                        $value .= $child->attr('text');
                    }
                    else {
                        $value .= $child;
                    }
                }
                $value;
            } $trs_comments->find('td');
        }

        my $command = Parse::Selenese::Command->new( \@values );
        push( @commands, $command );
    }
    $self->commands( \@commands );
    $tree = $tree->delete;
}

sub as_perl {
    my $self = shift;

    my $perl_code = '';
    foreach my $command ( @{ $self->{commands} } ) {
        my $code = $command->as_perl;
        $perl_code .= $code if defined $code;
    }
    chomp $perl_code;

    my @args =
      ( $self->{base_url}, Text::MicroTemplate::encoded_string($perl_code) );

    my $renderer = Text::MicroTemplate::build_mt($_test_mt);
    return $renderer->(@args)->as_string;
}


sub save {
    my $self = shift;
    my $file = shift;

    my $filename = $self->filename;
    $filename = $file if $file;

    open my $fh, '>', $filename
        or die "Can't write to '$filename': $!\n";
    print $fh $self->as_html;
    close $fh;

}

sub as_html {
    my $self = shift;
    my $tt   = Template->new();

    my $output = '';
    my $vars   = {
        commands => $self->commands,
        base_url => $self->base_url,
        thead    => $self->thead,
        title    => $self->title,
    };
    $tt->process( \$_selenese_testcase_template2, $vars, \$output );
    return Encode::decode_utf8 $output;
}

$_test_mt = <<'END_TEST_MT';
? my $base_url  = shift;
? my $perl_code = shift;
#!/usr/bin/perl
use strict;
use warnings;
use Time::HiRes qw(sleep);
use Test::WWW::Selenium;
use Test::More "no_plan";
use Test::Exception;
use utf8;

my $sel = Test::WWW::Selenium->new( host => "localhost",
                                    port => 4444,
                                    browser => "*firefox",
                                    browser_url => "<?= $base_url ?>" );

<?= $perl_code ?>
END_TEST_MT

$_selenese_testcase_template = <<'END_SELENESE_TESTCASE_TEMPLATE';
[% FOREACH command = commands -%]
[% command.as_html %]
[% END %]
END_SELENESE_TESTCASE_TEMPLATE

$_selenese_testcase_template2 = <<'END_SELENESE_TESTCASE_TEMPLATE';
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head profile="http://selenium-ide.openqa.org/profiles/test-case">
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
<link rel="selenium.base" href="[% base_url %]" />
<title>[% title %]</title>
</head>
<body>
<table cellpadding="1" cellspacing="1" border="1">
<thead>
<tr><td rowspan="1" colspan="3">[% thead %]</td></tr>
</thead><tbody>
[% FOREACH command = commands -%]
[% command.as_html %][% END %]</tbody></table>
</body>
</html>
END_SELENESE_TESTCASE_TEMPLATE

1;
__END__

=head1 Parse Selenium
I like to parse selenium
