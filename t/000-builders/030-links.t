#!perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;
use Test::Moose;

BEGIN {
    use_ok('PONAPI::Builder::Links');
    use_ok('PONAPI::Builder::Document');
}

subtest '... testing constructor' => sub {

    my $b = PONAPI::Builder::Links->new;
    isa_ok( $b, 'PONAPI::Builder::Links');
    does_ok($b, 'PONAPI::Builder');
    does_ok($b, 'PONAPI::Builder::Role::HasMeta');

    can_ok( $b, $_ ) foreach qw[
        has_links
        has_link

        get_link

        add_link
        add_links
        add_meta

        build
    ];

};

done_testing;
