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
my @mayor = ( 0, 2, 4, 5, 7, 9, 11, 12 );
my @minor = ( 0, 2, 3, 5, 7, 8, 10, 12 );
my @penta = ( -5, -2, 0, 2, 3, 5 );

my @alturas = map { 
    $_ + $tonica + ( 12 * $octave ) 
} @penta;
my $cantidad_alturas = scalar @alturas;


########################################
# Duraciones

my @duraciones = ( 
   1, 0.5, 0.5, 1, 1, 
);
my $cantidad_duraciones = scalar @duraciones;


########################################
# Secuencia de alturas ( @altura[n] )
# todo: duration if secuence not change ej: (1,1,1,1);
my @secuencia = ( 1..12 ); 

########################################
# Melodia

# Midi Setup
my @events = (
    ['set_tempo', 0, 450_000], # 1qn = .45 seconds
);

for my $delta ( reverse @secuencia ){
    my $altura = @alturas[ ( $delta - 1) % $cantidad_alturas ] ;
    my $duracion = 96 * @duraciones[ ( $delta - 1) % $cantidad_duraciones ] ;
    say $altura;

    push @events,
       ['note_on' , $duracion / 2 , 1, $altura, 127],
       ['note_off', $duracion, 1, $altura, 127],
    ;
}


my $klavier_track = MIDI::Track->new({ 
    'events' => \@events 
});

my $opus = MIDI::Opus->new({
    'format' => 1, 
    'tracks' => [ $klavier_track] 
});

$opus->write_to_file( 'melody.mid' );
