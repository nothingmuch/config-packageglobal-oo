#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';

{
	package Module::Crappy;

	our ( $scalar_conf, @array_conf ) = ( "foo", 1, 2, 3 );

	my $conf = "moose";
	sub sub_conf {
		$conf = shift if @_;
		$conf;
	}

	sub some_action {
		return [
			$scalar_conf,
			$conf,
			[ @array_conf ],
		];
	}
}

my $m; use ok $m = "Config::PackageGlobal::OO";

my $defaults = [ "foo", "moose", [ 1, 2, 3 ] ];

is_deeply( Module::Crappy::some_action(), $defaults , "current values" );

can_ok($m, "new");
isa_ok(my $o = $m->new("Module::Crappy", "some_action"), $m);

is( $o->scalar_conf, "foo", "scalar accessor" );
is_deeply( [ $o->array_conf ], [ 1, 2, 3 ], "array accessor" );
is( $o->sub_conf, "moose", "sub accessor" );

$o->scalar_conf( "new-val" );
is( $o->scalar_conf, "new-val", "scalar accessor also sets" );

is_deeply( [ $o->array_conf(qw/a b c/) ], [qw/a b c/], "array accessor also sets" );

$o->sub_conf("elk");
is( $o->sub_conf, "elk", "sub accessor also sets" );

is_deeply( Module::Crappy::some_action(), $defaults , "original values not changed" );

is_deeply( $o->some_action(), [ "new-val", "elk", [qw/a b c/] ], "values temporarily changed" );

is_deeply( Module::Crappy::some_action(), $defaults , "original values not changed" );
