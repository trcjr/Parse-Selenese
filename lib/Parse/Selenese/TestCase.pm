use Carp ();
use Encode;
use File::Basename;
use HTML::TreeBuilder;
use Parse::Selenese::Command;
use Parse::Selenese::TestCase;
use Text::MicroTemplate;
use Template;

use Data::Dumper;
$Data::Dumper::Indent = 1;
use HTML::Element;
use Modern::Perl;

package Parse::Selenese::TestCase;
use Moose;

with 'Parse::Selenese';

my ($_test_mt, $_selenese_testcase_template, $_selenese_testcase_template2);

has 'commands' =>
  ( isa => 'ArrayRef', is => 'rw', required => 0, default => sub { [] } );


around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    if ( @_ == 1 && !ref $_[0] ) {
        return $class->$orig( filename => $_[0], ) if -e $_[0];
        return $class->$orig( content => $_[0], );
    }
    elsif ( @_ == 1 && ref $_[0] ) {
        return $class->$orig( commands => $_[0], );
    }
    else {
        return $class->$orig(@_);
    }
};

sub short_name {
    my $self = shift;
    my $x    = File::Basename::basename( $self->filename );
    return ( File::Basename::fileparse( $x, qr/\.[^.]*/ ) )[0];
}

sub parse {
    my $self    = shift;
    #if (defined ( $self->filename )) {
    #    die " Can't read " . $self->filename unless -r $self->filename;
    #}

    return unless my $tree = $self->_parse;
    #use Data::Dumper;
    #warn Dumper $tree;

    # <tbody>以下からコマンドを抽出
    return unless my $tbody = $tree->find('tbody');
    my @commands;
    foreach my $trs_comments ( $tbody->find( ( 'tr', '~comment' ) ) ) {
        my @values;
        if ( $trs_comments->tag() eq '~comment' ) {
            @values = ('comment', $trs_comments->attr('text'), '');
        }
        elsif ( $trs_comments->tag() eq 'tr' ) {

            # 各<td>についてその下のHTMLを抽出する
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

    # テンプレートに渡すパラメータ
    my @args =
      ( $self->{base_url}, Text::MicroTemplate::encoded_string($perl_code) );

    my $renderer = Text::MicroTemplate::build_mt($_test_mt);
    return $renderer->(@args)->as_string;
}

sub as_html {
    my $self = shift;
    my $tt = Template->new();

    my $output = '';
    my $vars = {
        commands => $self->commands,
        base_url => $self->base_url,
        thead => $self->thead,
        title => $self->title,
    };
    $tt->process(\$_selenese_testcase_template2, $vars, \$output);
    return $output;
}

$_test_mt =<<'END_TEST_MT';
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

$_selenese_testcase_template=<<'END_SELENESE_TESTCASE_TEMPLATE';
[% FOREACH command = commands -%]
[% command.as_html %]
[% END %]
END_SELENESE_TESTCASE_TEMPLATE

$_selenese_testcase_template2=<<'END_SELENESE_TESTCASE_TEMPLATE';
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
