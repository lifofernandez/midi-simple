#!/usr/bin/env perl

use feature 'say';
use strict;
use Data::Dumper;
use MIDI;
use YAML::XS 'LoadFile';

########################################
# General setup

my $pulso = 1000_000; # milisecs 
my @confs = ( 
    'tracks/drum.yaml',
    #   'tracks/bajo.yaml',
);
my @tracks;


foreach ( @confs ){
    
    ########################################
    # load track from YAML
    # my $conf = LoadFile( 'tracks/bajo.yaml' );
    my $conf = LoadFile( $_ );
    
    # Track Setup
    say $conf->{ nombre };
    my $canal = $conf->{ canal };
    my $programa = $conf->{ programa };
    
    
    ########################################
    # Alturas
    
    my $tonica = $conf->{ tonica };
    my $octava = $conf->{ octava };
    my @escala = @{ $conf->{ escala }{ alturas } };
    my @alturas = map { 
        $_ + $tonica + ( 12 * $octava ) 
    } @escala;
    my $cantidad_alturas = scalar @alturas;
    
    
    ########################################
    # Duracion
    
    my @duraciones = @{ $conf->{ duraciones } };
    my $cantidad_duraciones = scalar @duraciones;
    my $retraso = $conf->{ retraso }; 
    # To do: note end overlap
    
    
    ########################################
    # Dinamica
    
    my @dinamicas = @{ $conf->{ dinamicas } }; 
    my $cantidad_dinamicas = scalar @dinamicas;
    my $piso = $conf->{ piso }; 
    my $variacion = $conf->{ variacion }; 
    
    
    ########################################
    # Secuencia de alturas ( @altura[ n ] )
    
    my @motivios = @{ $conf->{ secuencia } };
    my $repeticiones = $conf->{ repeticiones };
    
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
        [ 'patch_change', 1, $canal, $programa ], # 1qn = 1000 miliseconds
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
	# my $compresion = $piso + rand ( $variacion ); # variacion y compresion dinamica 
        my $compresion = $piso; # variacion y compresion dinamica 
        push @events, (
	    [ 'note_on' , $retraso, $canal, $altura, $dinamica * $compresion ],
	    [ 'note_off', $duracion, $canal, $altura, 0 ]
        );
        $index++;
    }
    
    my $track = MIDI::Track->new({ 
        'events' => \@events 
    });
    push @tracks, $track;

}
print Dumper( @tracks);
my $opus = MIDI::Opus->new({
    'format' => 1, 
    'tracks' => \@tracks 
});

$opus->write_to_file( 'output/melody.mid' );

