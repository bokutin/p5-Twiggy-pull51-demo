use strict;
use PadWalker qw(peek_sub);

# plackup -s Twiggy

sub _body {
    my $self = ${peek_sub(Twiggy::Server->can('run'))->{'$self'}};
    my $cv   = $self->{exit_guard};
    my $num  = $cv->{_ae_counter};
    my $body = <<HTML;
        _ae_counter:$num<br>
        <br>
        <a href="/">link:/</a><br>
        <a href="/delayed">link:/delayed</a><br>
        <a href="/async_without_lag">link:/async_without_lag</a><br>
        <a href="/async_with_lag">link:/async_with_lag</a> <span style="color:red">_ae_counter does not return to 2.</a><br>
HTML

}

my $w1;
my $w2;
sub {
    my ($env) = @_;

    if ($env->{PATH_INFO} eq '/') {
        [ 200, [ "Content-type", "text/html" ], [ _body ] ];
    }
    elsif ($env->{PATH_INFO} eq '/delayed') {
        sub {
            my ($respond) = @_;
            my $writer = $respond->([ 200, [ "Content-type", "text/html" ]]);
            $writer->write( _body );
            $writer->close;
        };
    }
    elsif ($env->{PATH_INFO} eq '/async_without_lag') {
        sub {
            my ($respond) = @_;
            my $writer = $respond->([ 200, [ "Content-type", "text/html" ]]); # get $writer without lag.
            $w1 = AnyEvent->timer(
                after => 0.01,
                cb    => sub {
                    $writer->write( _body );
                    $writer->close;
                    undef $w1;
                },
            );
        };
    }
    elsif ($env->{PATH_INFO} eq '/async_with_lag') {
        sub {
            my ($respond) = @_;
            $w2 = AnyEvent->timer(
                after => 0.01,
                cb    => sub {
                    my $writer = $respond->([ 200, [ "Content-type", "text/html" ]]); # get $writer with lag.
                    $writer->write( _body );
                    $writer->close;
                    undef $w2;
                },
            );
        };
    }
    else {
        [ 404, [ "Content-type", "text/html" ], [ "404 not found." ] ];
    }
};
