#!/usr/bin/env perl
# MIDI sequencer
# 
# Lisandro Fernández 2017



use feature 'say';
use strict;
use Data::Dumper;
use MIDI;
use YAML::XS 'LoadFile';

########################################
# General setup
my $bpm = 80;

my $pulso = ( 1000 / $bpm ) . '_000'; # mili
my $tic = 240; 
my @confs = ( 
   'tracks/drums.yml',
   'tracks/cymbals.yml',
   'tracks/bajo.yml',
);
my @tracks;


foreach ( @confs ){

    ########################################
    # Load track from YAML
    my $conf = LoadFile( $_ );

    # Track setup
    my $nombre = $conf->{ nombre };
    my $canal = $conf->{ canal };
    my $programa = $conf->{ programa };

    ########################################
    # Alturas

    my $tonica = $conf->{ tonica };
    my $octava = $conf->{ octava };

    # Revisar esto (es para soportar rangos)
    my @alturas = map {
        eval $_
    } @{ $conf->{ escala }{ alturas } };

    my @escala = map {
        $_ + $tonica + ( 12 * $octava ) 
    } @alturas;
    my $cantidad_alturas = scalar @escala;


    ########################################
    # Duracion

    my @duraciones = @{ $conf->{ duraciones } };
    my $cantidad_duraciones = scalar @duraciones;
    my $retraso = $conf->{ retraso };
    # To do: superposicion de las notas


    ########################################
    # Dinamica

    my @dinamicas = @{ $conf->{ dinamicas } }; 
    my $cantidad_dinamicas = scalar @dinamicas;
    my $variacion = $conf->{ variacion }; 
    my $piso = $conf->{ piso }; 


    ########################################
    # Secuencia de alturas ( @escala[ n ] )

    my @motivos = @{ $conf->{ secuencia_motivica } };
    my $repeticiones = $conf->{ repeticiones };

    my @secuencia;
    foreach ( @motivos ){
        my @motivo = @{ $_->{ orden } };

        # manipulacion motivica
        if ( $_->{ reverse } ){
            @motivo = reverse @motivo;
        }
        if ( $_->{ matriz } ){
            #@motivo = reverse @motivo;
        }
        push @secuencia, @motivo;
    }

    push @secuencia, ( @secuencia ) x $repeticiones;
    print Dumper( @secuencia );

    ########################################
    # Construir

    # Setup
    my @events = (
        [ 'set_tempo', 0, $pulso ],
        [ 'text_event', 0, "Track: ".$nombre ],
        [ 'patch_change', 0, $canal, $programa ],
    );

    my $index = 0;
    my $momento = 0;
    foreach (
        # reverse
        @secuencia 
    ){
        my (
            $delta, # posicion en las lista de alturas
            $transpo
        ) = split;

        my $altura = @escala[ ( $delta - 1 ) % $cantidad_alturas ] + $transpo;

        my $duracion = $tic * @duraciones[ $index % $cantidad_duraciones ] ;
        my $dinamica = 127 * @dinamicas[ $index % $cantidad_dinamicas ] ;
        my $compresion = $piso + rand ( $variacion );

        my $inicio = $tic * $retraso;
        my $final  = $duracion;

        push @events, (
            [ 'note_on' , $inicio, $canal, $altura, $dinamica * $compresion ],
            [ 'note_off', $final, $canal, $altura, 0 ]
        );
        $momento += $duracion;
        $index++;
    }

    my $track = MIDI::Track->new({
        'events' => \@events
    });
    push @tracks, $track;
}

my $opus = MIDI::Opus->new({
    'format' => 1,
    'ticks' => $tic,
    'tracks' => \@tracks
});
$opus->write_to_file( 'output/opus.mid' );

