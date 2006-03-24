#!/usr/bin/perl

package Config::PackageGlobal::OO;

use strict;
use warnings;

use Carp ();

use Context::Handle ();
use Devel::Symdump ();

sub new {
	my ( $class, $pkg, @methods ) = @_;

	my %methods;
	foreach my $method ( @methods ) {
		no strict 'refs';
		$methods{$method} = \&{ $pkg . "::" . "$method" }
			|| Carp::croak("The function '$method' does not exist in $pkg");
	}

	bless {
		pkg => $pkg,
		methods => \%methods,
		conf => { },
		conf_subs => { },
	}, $class;
}

my %sub_cache;
sub AUTOLOAD {
	my ( $self, @args ) = @_;
	my ( $method ) = ( our $AUTOLOAD =~ /([^:]+)$/ );

	if ( my $sub = $self->{methods}{$method} ) {
		my $prev = $self->_set_conf( $self->{conf} );

		local $@;
		my $rv = Context::Handle->new(sub {
			eval { $sub->( @args ) };
		});

		$self->_set_conf( $prev );
		die $@ if $@;

		# $rv->return barfs here, either because of the goto or because of the AUTOLOAD
		# bus error in autoload, illegal instruction in goto
		return $rv->value;
	} else {
		unless ( exists $self->{conf}{$method} ) {
			# initial value is copied from package
			$self->{conf}{$method} = $self->_conf_accessor( $method );
		}

		$self->{conf}{$method} = \@args if @args;

		return scalar @{ $self->{conf}{$method} } != 1 ? @{ $self->{conf}{$method} } : $self->{conf}{$method}[0];
	}
}

sub _set_conf {
	my ( $self, $conf ) = @_;

	my %prev;

	foreach my $key ( keys %$conf ) {
		$prev{$key} = $self->_set_conf_key( $key, $conf->{$key} );
	}

	\%prev;
}

sub _conf_accessor {
	my ( $self, $key ) = ( shift, shift );

	my $accessor = $sub_cache{$self->{pkg}}{$key} ||= do {
		no strict 'refs';
		my $sub;
		my $sym = $self->{pkg} . '::' . $key;

		if ( *$sym{CODE} ) {
			my $orig = \&{$sym};
			$sub = sub { [ $orig->(@_) ] }
		} elsif ( *$sym{ARRAY} ) {
			my $var = \@{$sym};
			$sub = sub {
				@$var = @_ if @_;
				[ @$var ];
			}
		} else {
			my $var = \${$sym};
			$sub = sub {
				$$var = shift if @_;
				warn "setting to @_" if @_;
				[ $$var ];
			};
		}

		$sub_cache{$self->{pkg}}{$key} = $sub;
	};

	$accessor->( @_ );
}

sub _set_conf_key {
	my ( $self, $key, $new ) = @_;

	my $prev = $self->_conf_accessor( $key );
	$self->_conf_accessor( $key, @$new );
	return $prev;
}

sub DESTROY { }

__PACKAGE__;

__END__

=pod

=head1 NAME

Config::PackageGlobal::OO - A generic configuration object for modules with package global configuration

=head1 SYNOPSIS

	use Hash::Merge;
	use Config::PackageGlobal::OO;

	my $o = Config::PackageGlobal::OO->new( "Hash::Merge", qw/merge/ );

	$o->set_behavior( RIGHT_PRECEDENT );

	my $rv = $o->merge( $hash, $other );

	Hash::Merge::set_behavior(); # this is returned to it's previous value

=head1 DESCRIPTION

=cut


