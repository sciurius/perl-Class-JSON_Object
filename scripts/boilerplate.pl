#!/usr/bin/perl

use v5.36;
use Object::Pad;
use Class::JSON_Object;
use feature qw(signatures);
no feature qw(indirect);
use utf8;

# Author          : Johan Vromans
# Created On      : Thu Jan 25 19:14:38 2024
# Last Modified By: Johan Vromans
# Last Modified On: Wed May  6 20:34:36 2026
# Update Count    : 127
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;

# Package name.
my $my_package = 'Sciurix';
# Program name and version.
my ($my_name, $my_version) = qw( gen 0.01 );

################ Command line parameters ################

use Getopt::Long 2.13;

# Command line options.
my $select;
my $prefix;
my $outfile;
my $verbose = 1;		# verbose processing

# Development options (not shown with -help).
my $debug = 0;			# debugging
my $trace = 0;			# trace (show process)
my $test = 0;			# test mode.

# Process command line options.
app_options();

# Post-processing.
$trace |= ($debug || $test);

################ Presets ################

my $TMPDIR = $ENV{TMPDIR} || $ENV{TEMP} || '/usr/tmp';
binmode( STDOUT, ':utf8' );
binmode( STDERR, ':utf8' );

################ The Process ################

use File::LoadLines qw(loadblob);
use JSON::PP;

my $json = JSON::PP->new->utf8->relaxed;

if ( $outfile ) {
    open( STDOUT, '>:utf8', $outfile ) ||die("$outfile: $!\n");
}

my %classes;

for my $file ( @ARGV ) {
    my $data = $json->decode( loadblob( $file ) );
    my $prefix = $prefix;

    if ( $select ) {
	my $p;
	for ( split( ':', $select ) ) {
	    $p = $_;
	    $data = $data->{$p} or die("Select $select: No such element: $p\n");
	}
	$prefix //= ucfirst($p);
    }
    $prefix //= "Class";
    generate( $data, $prefix );
}

print( "# WARNING: This is generated boiler plate code. Please adjust.\n\n" );

for my $cls ( sort keys %classes ) {
    my $class = $classes{$cls};
    print( "class ", $class->name, " :does(Class::JSON_Object) {\n" );

    # Length of excess field names.
    my $len = 3 + 3*8;
    $len = $class->lfn if $class->lfn > $len;
    $len++;
    my $fmt = "    field %-${len}s\t%s\n";

    for my $fn ( sort { substr($a,1) cmp substr($b,1) } $class->fieldnames ) {
	my $field = $class->get_field($fn);
	my $xtra = "";
	my $name = $field->name;
	if ( $class->seen != $field->seen ) {
	    $xtra .= " " if $xtra;
	    $xtra .= ":Optional";
	}
	if ( $field->type ) {
	    $xtra .= " " if $xtra;
	    $xtra .= ":Class(" . $field->type . ")";
	}

	if ( $xtra ) {
	    $xtra .= ";\t# ";
	}
	else {
	    $name .= ";";
	    $xtra = "# ";
	}
	printf( $fmt, $name, $xtra );
    }

    print( "}\n\n" );
}


################ Classes ################

class Field :does(Class::JSON_Object) {
    field $name			:param;	# includes sigil
    field $type			:mutator; # if class
    field $seen			:mutator;
}

class Class :does(Class::JSON_Object) {
    field $name			:param;
    field $lfn = -1;		# longest field name
    field %fields;		# fields
    field $seen			:mutator;

    method add_field( $f ) {
	$f = $fields{$f->name} //= $f;
	$f->seen++;
	$lfn = length($f->name) if length($f->name) > $lfn;
    }

    method fieldnames() { keys %fields }
    method get_field( $name ) { $fields{$name} }
}

################ Subroutines ################

sub generate( $data, $pfx ) {

    my $class = $classes{$pfx} //= Class->new( name => $pfx );
    $class->seen++;

    for my $field ( sort keys %$data ) {
	$field  =~ s/-/_/g;
	for ( split(/,\s*/, $field) ) {
	    my $field = $_;
	    my $f;
	    my $v = $data->{$field};

	    # ARRAY.
	    if ( ref($v) eq 'ARRAY' ) {
		$f = Field->new( name => "\@$field" );
		for ( my $i = 0; $i < @$v; $i++ ) {
		    my $v = $v->[$i];
		    if ( ref($v) eq 'HASH' ) {
			my $pfx = $pfx . "_" . $field;
			$f->type = $pfx;
			generate( $v, $pfx );
		    }
		}
	    }

	    # HASH -> Object.
	    elsif ( ref($v) eq 'HASH' ) {
		my $pfx = $pfx . "_" . $field;
		$f = Field->new( name => "\$$field", type => $pfx );
		generate( $v, $pfx );
	    }

	    # Scalar field.
	    else {
		$f = Field->new( name => "\$$field" );
	    }
	    $class->add_field($f);
	}
    }

}

################ Subroutines ################

sub app_options {
    my $help = 0;		# handled locally
    my $ident = 0;		# handled locally
    my $man = 0;		# handled locally

    my $pod2usage = sub {
        # Load Pod::Usage only if needed.
        require Pod::Usage;
        Pod::Usage->import;
        &pod2usage;
    };

    # Process options.
    if ( @ARGV > 0 ) {
	GetOptions( 'select=s'  => \$select,
		    'prefix=s'	=> \$prefix,
		    'output=s'	=> \$outfile,
		    'ident'	=> \$ident,
		    'verbose+'	=> \$verbose,
		    'quiet'	=> sub { $verbose = 0 },
		    'trace'	=> \$trace,
		    'help|?'	=> \$help,
		    'man'	=> \$man,
		    'debug'	=> \$debug )
	  or $pod2usage->( -exitval => 2, -verbose => 0 );
    }
    if ( $ident or $help or $man ) {
	print STDERR ("This is $my_package [$my_name $my_version]\n");
    }
    if ( $man or $help ) {
	$pod2usage->( -exitval => 0, -verbose => $man ? 2 : 0 );
    }
}

__END__

################ Documentation ################

=head1 NAME

boilerplate - generate boilerplate for Class::JSON_Object

=head1 SYNOPSIS

boilerplate [options] [file ...]

 Options:
   --select XX:YY	start with ->{XX}->{YY}
   --prefix XXX         Prefix for classes
   --output FILE        output file
   --ident		shows identification
   --help		shows a brief help message and exits
   --man                shows full documentation and exits
   --verbose		provides more verbose information
   --quiet		runs as silently as possible

=head1 OPTIONS

=over 8

=item B<--select=>I<XXX>

Instead of the top level object, start with top->{XXX}.

I<XXX> may be a series of objects separated by colons.

E.g., C<ResultObj:containers> will start generating at
top->{ResultObj}->{containers}.

=item B<--prefix=>I<XXX>

The prefix for the top level class. Child classes will have their name
appended, separated by an underscore.

E.g., if C<ResultObj:containers> has a field C<metadata> which is
another object, its class will become
C<ResultObj_containers_metadata>.

=item B<--output=>I<XXX>

Write the output to file I<XXX>. Default is to write to standard output.

=item B<--help>

Prints a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<--ident>

Prints program identification.

=item B<--verbose>

Provides more verbose information.
This option may be repeated to increase verbosity.

=item B<--quiet>

Suppresses all non-essential information.

=item I<file>

The input file(s) to process. These must be valid JSON data files.

=back

=head1 DESCRIPTION

This program will read the given input file and produce boiler
plate code for Class::JSON_Object classes.

=head1 EXAMPLE

Given a JSON data file with content:

    { "op" : {
          "control" : "process",
	  "data" : {
              "operation": "copy",
              "args": [ 47, 11 ]
          },
	  "result" : "OK"
    } }

This will produce the following boilerplate code (with C<--prefix=Op>):

    class Op_data :does(Class::JSON_Object) {
	field @args;                       	# 
	field $operation;                  	# 
    }

    class Op :does(Class::JSON_Object) {
	field $control;                    	# 
	field $data                        	:Class(Op_data);
	field $result;                     	# 
    }

=head1 SEE ALSO

This program is part of L<Class::JSON_Object>. See.

=cut

