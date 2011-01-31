use strict;
package Parse::Selenese::Command;
use Carp ();
use HTML::TreeBuilder;
use Parse::Selenese::TestCase;
use Moose;

has 'values' =>
  ( isa => 'ArrayRef', is => 'rw', required => 0, default => sub { [] } );

#use 5.008_001;
#our $VERSION = '0.01';

#require Exporter;
#our @EXPORT_OK = qw(values_to_perl);
#*import = \&Exporter::import;


my %command_map = (
    # a comment
    comment => {  # Selenese command name
        func => '#',  # method name in Test::WWW::Selenium
        args => 1,    # number of arguments to pass
    },

    # opens a page using a URL.
    open => {  # Selenese command name
        func => 'open_ok',  # method name in Test::WWW::Selenium
        args => 1,          # number of arguments to pass
    },

    # performs a click operation, and optionally waits for a new page to load.
    click => {
        func => 'click_ok',
        args => 1,
    },
    clickAndWait => {
        func => [  # combination of methods
            {
                func => 'click_ok',
                args => 1,
            },
            {
                func => 'wait_for_page_to_load_ok',
                force_args => [ 30000 ],  # force arguments to pass
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
        func   => 'wait_for_page_to_load_ok',
        args => 1,
    },

    # pauses execution until an expected UI element,
    # as defined by its HTML tag, is present on the page.
    waitForElementPresent => {
        wait => 1,  # use WAIT structure
        func => 'is_element_present',
        args => 1,
    },

    # store text in the variable.
    storeText => {
        args  => 1,
        store => 1,
        func  => 'get_text',
    },
    storeTextPresent => {
        args  => 1,
        store => 1,  # store value in variable
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
        $line = turn_func_into_perl($code, @args);
    }
    if ($line) {
        return $line."\n";
    } else {
        return undef;
    }
}

# %command_mapの1エントリと引数を受け取り、Perlスクリプトに変換して返す
sub turn_func_into_perl {
    my ($code, @args) = @_;

    my $line = '';
    if ( ref($code->{func}) eq 'ARRAY' ) { # 複数のPerl文で構成される場合
        foreach my $subcode (@{ $code->{func} }) {
            $line .= "\n" if $line;
            $line .= turn_func_into_perl($subcode, @args);
        }
    } else { # 単一のPerl文で構成される場合
        if ( $code->{func} eq '#' ) {    # Comment
            $line = $code->{func} . make_args( $code, @args );
#        } elsif ( $code->{test} ) { # testパラメータがある場合はそれを関数として呼ぶ
#            $line = $code->{test}.'($sel->'.$code->{func}.', '.make_args($code, @args).');';
        } elsif ( $code->{store} ) { # 変数に代入する場合
            my $varname = pop @args;
            $line = "my \$$varname = \$sel->".$code->{func}.'('
                    . make_args($code, @args).');';
        } else { # $selオブジェクトのメソッドを呼ぶ
            $line = '$sel->'.$code->{func}.'('
                    . make_args($code, @args).');';
        }
        if ( $code->{repeat} ) { # 繰り返しがある場合は行を複製
            my @lines;
            push(@lines, $line) for (1..$code->{repeat});
            $line = join("\n", @lines);
        }
        if ( $code->{wait} ) { # WAIT構造を使用する場合
            $line =~ s/;$//;
            $line = <<EOF;
WAIT: {
    for (1..60) {
        if (eval { $line }) { pass; last WAIT }
        sleep(1);
    }
    fail("timeout");
}
EOF
            chomp $line;
        }
    }
    return $line;
}

# メソッドの引数を作って返す
sub make_args {
    my ($code, @args) = @_;

    my $str = '';
    if ( $code->{force_args} ) { # 引数が強制的に指定される場合
        $str .= join(', ', map { quote($_) } @{ $code->{force_args} });
    } else {
        if ( defined $code->{args} ) { # 引数の個数が指定されている場合
            @args = map { defined $args[$_] ? $args[$_] : '' } (0..$code->{args}-1);
        }
        # 値の先頭の exact: を削除
        map { s/^exact:// } @args;
        # 引数をカンマで結合する

        if ( $code->{func} eq '#' ? 0 : 1 ) {
            $str .= join(', ', map { quote($_) } @args);
        } else {
            $str .= join(', ', @args);
        }
    }

    return $str;
}

# エスケープした上でダブルクオーテーションで囲った文字列を返す
sub quote {
    my $str = shift;

    $str =~ s,<br />,\\n,g;
    $str =~ s/\Q$_\E/\\$_/g for qw(" % @ $);
    $str = '"'.$str.'"';
    return $str;
}

1;
