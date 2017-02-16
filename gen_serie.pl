#!/usr/bin/env perl

use feature 'say';
use strict;
use Data::Dumper;
use MIDI;
use YAML::XS 'LoadFile';

########################################
# General setup

my $pulso = 1000_000; # milisecs 


########################################
# Track config from YAML
my $track_config = LoadFile( 'tracks/bajo.yaml' );

my $canal = $track_config->{ canal };


########################################
# Alturas

my $tonica = $track_config->{ tonica };
my $octava = $track_config->{ octava };
my @escala = @{ $track_config->{ escala }{ alturas } };

my @alturas = map { $_ + $tonica + ( 12 * $octava ) 
} @escala;
my $cantidad_alturas = scalar @alturas;


########################################
# Duracion

my @duraciones; 
push ( @duraciones, ( "1" ) );
my $cantidad_duraciones = scalar @duraciones;
my $retardo = 10; #revisar esto 


########################################
# Dinamica

my @dinamicas = @{ $track_config->{ dinamicas } }; 
my $cantidad_dinamicas = scalar @dinamicas;


########################################
# Secuencia de alturas ( @altura[ n ] )

my @motivios = @{ $track_config->{ secuencia } };
my $repeticiones = $track_config->{ repeticiones };

my @secuencia;  
foreach ( @motivios ){
    push @secuencia,  @{ $_->{ orden } };
}
push @secuencia, ( @secuencia ) x $repeticiones;


########################################
# Construir 

# Setup
my @events = (
    [ 'set_tempo', 0, $pulso ], # 1qn = 1000 miliseconds
    [ 'patch_change', 1, 1, $canal ], # 1qn = 1000 miliseconds
);

my $index = 0;
foreach ( 
	# reverse
	@secuencia 
){
    my ( 
        $delta, # posicion en las lista de alturas
	$transpo
    ) = split;
    my $altura = @alturas[ ( $delta - 1) % $cantidad_alturas ] + $transpo;
    my $duracion = 96 * @duraciones[ $index % $cantidad_duraciones ] ;
    my $dinamica = 127 * @dinamicas[ $index % $cantidad_dinamicas ] ;
    my $variacion = .5 + rand ( .3 ); # variacion y compresion dinamica 
    push @events,
        [ 'note_on' ,  $retardo, $canal, $altura, $dinamica * $variacion ],
        [ 'note_off', $duracion, $canal, $altura, 1 ];
    $index++;
}


my $piano_track = MIDI::Track->new({ 
    'events' => \@events 
});

my $opus = MIDI::Opus->new({
    'format' => 1, 
    'tracks' => [ $piano_track ] 
});

$opus->write_to_file( 'output/melody.mid' );

