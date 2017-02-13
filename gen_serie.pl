#!/usr/bin/env perl

use feature 'say';
use strict;
use Data::Dump qw( dump );
use MIDI;


########################################
# Alturas

my $tonica= 60;
my $octave = -1;

my @chrom = ( 0 .. 12 );
my @mayor = ( 0, 2, 4, 5, 7, 9, 11 );
my @minor = ( 0, 2, 3, 5, 7, 8, 10, 12 );
my @penta = ( 0, 2, 3, 4, 5 );


my @alturas = map { 
    $_ + $tonica + ( 12 * $octave ) 
} @mayor;
my $cantidad_alturas = scalar @alturas;


########################################
# Duraciones

my @d1 = ( .5, .5, 1, 1, 1, 2);
my @d2 = ( .5, .5, 1, 2, .5, .5, 1, 2);
my @d2 = ( .5, .5, 1, 2, .5, .5, 1, 2);

my @duraciones;
push @duraciones, @d1, @d1, @d2, @d1;
my $cantidad_duraciones = scalar @duraciones;


########################################
# Secuencia de alturas ( @altura[n] )

my @A    = ( "5 -12", "5 -12", "6 -12", "5 -12", 1, "7 -12", ); 
my @Ap   = ( "5 -12", "5 -12", "6 -12", "5 -12", 2, 1 ); 
my @App  = ( "5 -12", "5 -12", 5, 3, 1, 1, "7 -12", "6 -12"); 
my @Appp = ( 4, 4, 3, 1, 2, 1 ); 
my @secuencia;  
push @secuencia, @A, @Ap, @App, @Appp;


########################################
# Melodia

# Midi Setup
my @events = (
    ['set_tempo', 0, 1000_000], # 1qn = 1000 miliseconds
);

my $index = 0;
foreach ( 
	# reverse
	@secuencia 
){
    my ( 
        $delta, # posicion en las lista de alturas
	$transpo
    ) = split ;
    say $delta;

    my $altura = @alturas[ ( $delta - 1) % $cantidad_alturas ] + $transpo;
    my $duracion = 96 * @duraciones[  $index % $cantidad_duraciones ] ;

    push @events,
       ['note_on' , 0, 1, $altura, 127],
	['note_off', $duracion, 1, $altura, 127],
    ;
    $index++;
}


my $klavier_track = MIDI::Track->new({ 
    'events' => \@events 
});

my $opus = MIDI::Opus->new({
    'format' => 1, 
    'tracks' => [ $klavier_track] 
});

$opus->write_to_file( 'melody.mid' );
