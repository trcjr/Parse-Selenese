use strict;
package Parse::Selenese::Command;
use Moose;
extends 'Parse::Selenese';
use Parse::Selenese::TestCase;
use Carp ();
use HTML::TreeBuilder;
use Template;

has 'values' =>
  ( isa => 'ArrayRef', is => 'rw', required => 0, default => sub { [] } );

has 'element' => (
    is      => 'ro',
    lazy    => 1,
    builder => '_element',
);

my $_selenese_command_template=<<'END_SELENESE_COMMAND_TEMPLATE';
<tr>
[% FOREACH value = values -%]
	<td>[% value %]</td>
[% END %]</tr>
END_SELENESE_COMMAND_TEMPLATE

my $_selenese_comment_template="<!--[% values.1 %]-->\n";

my %command_map = (

    # a comment
    comment => {    # Selenese command name
        func => '#',    # method name in Test::WWW::Selenium
        args => 1,      # number of arguments to pass
    },

    # opens a page using a URL.
    open => {           # Selenese command name
        func => 'open_ok',    # method name in Test::WWW::Selenium
        args => 1,            # number of arguments to pass
    },

    # performs a click operation, and optionally waits for a new page to load.
    click => {
        func => 'click_ok',
        args => 1,
    },
    clickAndWait => {
        func => [             # combination of methods
            {
                func => 'click_ok',
                args => 1,
            },
            {
                func => 'wait_for_page_to_load_ok',
                force_args => [30000],    # force arguments to pass
            },
        ],
    },

    # verifies an expected page title.
    verifyTitle => {
        func => 'title_is',
        args => 1,
    },
    assertTitle => {
        func => 'title_is',
        args => 1,
    },

    # verifies expected text is somewhere on the page.
    verifyTextPresent => {
        func => 'is_text_present_ok',
        args => 1,
    },
    assertTextPresent => {
        func => 'is_text_present_ok',
        args => 1,
    },

# verifies an expected UI element, as defined by its HTML tag, is present on the page.
    verifyElementPresent => {
        func => 'is_element_present_ok',
        args => 1,
    },
    assertElementPresent => {
        func => 'is_element_present_ok',
        args => 1,
    },

# verifies expected text and it's corresponding HTML tag are present on the page.
    verifyText => {
        func => 'text_is',
        args => 2,
    },
    assertText => {
        func => 'text_is',
        args => 2,
    },

    # verifies a table's expected contents.
    verifyTable => {
        func => 'table_is',
        args => 2,
    },
    assertTable => {
        func => 'table_is',
        args => 2,
    },

    # pauses execution until an expected new page loads.
    # called automatically when clickAndWait is used.
    waitForPageToLoad => {
        func => 'wait_for_page_to_load_ok',
        args => 1,
    },

    # pauses execution until an expected UI element,
    # as defined by its HTML tag, is present on the page.
    waitForElementPresent => {
        wait => 1,                      # use WAIT structure
        func => 'is_element_present',
        args => 1,
    },

    store => {
        args         => 1,
        store        => 1,
        pass_through => 1,
    },

    # store text in the variable.
    storeText => {
        args  => 1,
        store => 1,
        func  => 'get_text',
    },
    storeTextPresent => {
        args  => 1,
        store => 1,                   # store value in variable
        func  => 'is_text_present',
    },
    storeElementPresent => {
        args  => 1,
        store => 1,
        func  => 'is_element_present',
    },
    storeTitle => {
        args  => 0,
        store => 1,
        func  => 'get_title',
    },

    # miscellaneous commands
    waitForTextPresent => {
        wait => 1,
        func => 'is_text_present',
        args => 1,
    },

    # type text in the field.
    type => {
        func => 'type_ok',
        args => 2,
    },

    # select option from the <select> element.
    select => {
        func => 'select_ok',
        args => 2,
    },
);

# translate values to Perl code
#sub values_to_perl {
#    __PACKAGE__->new(shift)->as_perl;
#}

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
    #SUPER::BUILDARGS();

    if ( @_ == 1 && ref $_[0] ) {
        return $class->$orig( values => $_[0], );
    }
    else {
        return $class->$orig(@_);
    }
};

sub as_perl {
    my $self = shift;

    my $line;
    my $code = $command_map{ $self->{values}->[0] };
    my @args = @{ $self->{values} };
    shift @args;
    if ($code) {
        $line = turn_func_into_perl( $code, @args );
    }
    if ($line) {
        $line .= "\n";
    }
    return $line;
}

sub _element {
    my $self = shift;

    my $element = HTML::Element->new('tr');
    if ( $self->{values}->[0] eq "comment" ) {
        $element = HTML::Element->new('~comment');
        $element->attr( 'text', $self->{values}->[1] );

    }
    else {
        $element = HTML::Element->new('tr');
        foreach my $value ( @{ $self->{values} } ) {
            my $td = HTML::Element->new('td')->unshift_content($value);
            $element->push_content($td);
        }
    }
    return $element;
}

sub _get_template {
    my $self = shift;

    if ($self->element->tag eq "~comment") {
        return $_selenese_comment_template;
    }
    return $_selenese_command_template;
}

sub as_html {
    my $self = shift;
    my $tt = Template->new;
    my $template = $self->_get_template;
    my $output = '';
    my $vars = {
        values => $self->values,
    };
    $tt->process(\$template, $vars, \$output);
    return $output;
}

sub turn_func_into_perl {
    my ( $code, @args ) = @_;

    my $line = '';
    if ( ref( $code->{func} ) eq 'ARRAY' ) {
        foreach my $subcode ( @{ $code->{func} } ) {
            $line .= "\n" if $line;
            $line .= turn_func_into_perl( $subcode, @args );
        }
    }
    else {
        if ( defined $code->{func} && $code->{func} eq '#' ) {
            $line = $code->{func} . make_args( $code, @args );
        }
        elsif ( defined $code->{store} && $code->{store} ) {
            my $varname = pop @args;
            $line = 'my $' . "$varname = ";
            if ( $code->{func} ) {
                $line .=
                    "\$sel->"
                  . $code->{func} . '('
                  . make_args( $code, @args ) . ');';
            }
            else {
                $line .= make_args( $code, @args ) . ";";
            }
        }
        else {
            $line =
              '$sel->' . $code->{func} . '(' . make_args( $code, @args ) . ');';
        }

        #        if ( $code->{repeat} ) {
        #            my @lines;
        #            push( @lines, $line ) for ( 1 .. $code->{repeat} );
        #            $line = join( "\n", @lines );
        #        }
        if ( $code->{wait} ) {
            $line =~ s/;$//;
            $line = <<EOF;
WAIT: {
    for (1..60) {
        if (eval { $line }) { pass; last WAIT }
        sleep(1);
    }
    fail("timeout");
}
pass;
EOF
            chomp $line;
        }
    }
    return $line;
}

sub make_args {
    my ( $code, @args ) = @_;

    my $str = '';
    if ( $code->{force_args} ) {
        $str .= join( ', ', map { quote($_) } @{ $code->{force_args} } );
    }
    else {
        if ( defined $code->{args} ) {
            @args =
              map { defined $args[$_] ? $args[$_] : '' }
              ( 0 .. $code->{args} - 1 );
        }
        map { s/^exact:// } @args;

        if ( defined $code->{func} && $code->{func} eq '#' ? 0 : 1 ) {
            $str .= join( ', ', map { quote($_) } @args );
        }
        else {
            $str .= join( ', ', @args );
        }
    }

    return $str;
}

sub quote {
    my $str        = shift;
    my $quote_char = shift;

    $str =~ s,<br />,\\n,g;
    unless ( $str =~ s/^\$\{(.*)\}/\$$1/ ) {
        $str =~ s/\Q$_\E/\\$_/g for qw(" % @ $);
        $str = '"' . $str . '"';
    }
    return $str;
}

1;
