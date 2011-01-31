use Carp ();
use HTML::TreeBuilder;
use Parse::Selenese::TestCase;
use Parse::Selenese::Command;
use Text::MicroTemplate;
use File::Basename;
use Encode;

use Data::Dumper;
$Data::Dumper::Indent = 1;
use HTML::Element;
use Modern::Perl;

package Parse::Selenese::TestCase;
use Moose;

has 'filename' => ( isa => 'Str', is => 'rw', required => 0 );
has 'path' => ( isa => 'Str', is => 'rw', required => 0 );
has 'base_url' => ( isa => 'Str', is => 'rw', required => 0 );
has 'commands' =>
  ( isa => 'ArrayRef', is => 'rw', required => 0, default => sub { [] } );
has 'content' => ( isa => 'Str', is => 'rw', required => 0 );

#our $VERSION = '0.01';
#require Exporter;
#our @EXPORT_OK = qw(case_to_perl);
#*import = \&Exporter::import;

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    if ( @_ == 1 && !ref $_[0] ) {
        return $class->$orig( filename => $_[0], );
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
    $self->parse if $self->filename;
}

sub short_name {
    my $self = shift;
    my $x    = File::Basename::basename( $self->filename );
    return ( File::Basename::fileparse( $x, qr/\.[^.]*/ ) )[0];
}

sub parse {
    my $self = shift;
    my $filename = $self->filename or die "specify a filename";

    die "Can't read $filename" unless -r $filename;

    return if scalar @{$self->commands};
    return $self->_parse;
}

sub parse_content {
    my $self    = shift;
    my $content = shift;
    return $self->_parse($content);
}

sub _parse {
    my $self    = shift;
    my $content = shift;

    return if scalar @{$self->commands};

    my $tree = HTML::TreeBuilder->new;
    $tree->store_comments(1);
    if ( $self->filename ) {
        $tree->parse_file( $self->filename );
    }
    else {
        $tree->parse_content($content);
    }

    # base_urlを<link>から見つける
    foreach my $link ( $tree->find('link') ) {
        if ( $link->attr('rel') eq 'selenium.base' ) {
            $self->base_url( $link->attr('href') );
        }
    }

    # <tbody>以下からコマンドを抽出
    my $tbody = $tree->find('tbody');
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

    # test.mtをテンプレートとして読み込む
    warn File::Basename::dirname(__FILE__) . "/test.mt";
    open my $io, '<', File::Basename::dirname(__FILE__) . "/test.mt" or die $!;
    my $template = join '', <$io>;
    close $io;
    my $renderer = Text::MicroTemplate::build_mt($template);
    return $renderer->(@args)->as_string;
}

sub convert_to_perl {
    my $self = shift;

    my $outfile = $self->{filename};
    $outfile =~ s/\.html?$/.pl/;

    my $perl = $self->as_perl;

    open my $io, '>', $outfile or die $!;
    print $io $perl;
    close $io;

    return $outfile;
}

sub as_html {
    my $self = shift;

    my $title_text = "this is the title text";

    my $root  = HTML::TreeBuilder->new();
    my $head  = $root->find('head');
    my $table = HTML::Element->new(
        'table',
        cellpadding => 1,
        cellspacing => 1,
        border      => 1
    );
    my $meta = HTML::Element->new(
        'meta',
        'http-equiv' => "Content-Type",
        content      => "text/html; charset=UTF-8"
    );

    my $link = HTML::Element->new(
        'link',
        rel  => "selenium.base",
        href => "http://www.google.com/"
    );

    $root->find('body')->insert_element($table);
    my $thead = HTML::Element->new('thead');
    my $tr    = HTML::Element->new('tr');
    my $td    = HTML::Element->new( 'td', rowspan => 1, colspan => 3 );
    my $tbody = HTML::Element->new('tbody');

    $tr->insert_element($td);
    $td->unshift_content($title_text);

    $head->attr( 'profile',
        "http://selenium-ide.openqa.org/profiles/test-case" );

    $head->insert_element($meta);
    $head->insert_element($link);
    $thead->insert_element($tr);
    $table->push_content($thead);
    $table->push_content($tbody);
    foreach my $command ( @{ $self->{commands} } ) {
        my $element;
        if ( $command->{values}->[0] eq "comment" ) {

            $element = HTML::Element->new('~comment');
            $element->attr( 'text', $command->{values}->[1] );

        }
        else {
            $element = HTML::Element->new('tr');
            foreach my $value ( @{ $command->{values} } ) {
                my $td = HTML::Element->new('td')->unshift_content($value);
                $element->push_content($td);
            }
        }
        $tbody->push_content($element);
    }

    return $root->as_HTML( '<>&', "  " );

}

1;
