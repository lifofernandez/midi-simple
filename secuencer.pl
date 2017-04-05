#!/usr/bin/env perl

########################################
# Secuenciador Motivocentrico 

# Lisandro Fernández ( Febrero 2017 )

use feature 'say';
use strict;
use Data::Dump qw( dump );
use Data::Dumper;
use MIDI;
use YAML::XS 'LoadFile';

########################################
# CONSTANTES

my $pulso = 600_000; # mili
my $tic = 240; 

my @configs = <./tracks/*>;
my @tracks;

foreach ( @configs ){

    ########################################
    # Load track from YAML
    my $config_file = LoadFile( $_ );
    my %conf_global = %{ $config_file->{ global } } ;

    # Track setup
    my $nombre = $conf_global{ nombre };
    say $nombre;
    my $canal = $conf_global{ canal };
    my $programa = $conf_global{ programa };


    # ########################################
    # # Configuraciones generales

    # my $tonica = $conf->{ tonica };
    # my $octava = $conf->{ octava };

    # my @escala = map {
    #     eval $_ # Perl Ranges suport 
    # } @{ $conf->{ alturas } };

    # #my @alturas = map {
    # #    $_ + $tonica + ( 12 * $octava ) 
    # #} @escala;

    # my @duraciones = @{ $conf->{ duraciones } };
    # my $retraso = $conf->{ retraso };
    # # To do: superposicion de las notas

    # my @dinamicas = @{ $conf->{ dinamicas } };
    # my $piso = $conf->{ piso };
    # my $variacion = $conf->{ variacion };


    ########################################
    # Cargar Motivos
    # agregar config generales al motivo

    #my %MOTIVOS= ();
    #for my $ID( keys
    #    %{ $config_file->{ motivos } }
    #){
    #    my %motivo = %{ $config_file->{ motivos }{ $ID } };
    #    say " " . $ID;

    #    for my $prop_global (keys %conf_global){
    #        if ( !$motivo{ $prop_global } ){
    #            my $valor_global = $conf_global{ $prop_global };
    #            $motivo{$prop_global} = $valor_global;
    #        }
    #    }
    #    $MOTIVOS{ $ID } = \%motivo;
    #}
    #dump(%MOTIVOS);
    my %ESTRUCTURAS = ();
    for my $eID( 
        keys %{ $config_file->{ ESTRUCTURAS } }
    ){
        my %estructura = %{ $config_file->{ ESTRUCTURAS }{ $eID } };
        say "estructura: " . $eID;

        my %MOTIVOS = ();
        for my $mID(
            keys %{ $estructura{ MOTIVOS } }
        ){
            say "  motivo: " . $mID;
            my %motivo = %{ $estructura{ MOTIVOS }{ $mID } };

            # Agrego propiedades globales a los motivos
            for my $prop_global(
                keys %conf_global
            ){
                if ( !$motivo{ $prop_global } ){
                    my $valor_global = $conf_global{ $prop_global };
                    $motivo{ $prop_global } = $valor_global;
                }
            }

            $MOTIVOS{ $mID } = \%motivo;
        }
        $estructura{ MOTIVOS } = \%MOTIVOS;

        $ESTRUCTURAS{ $eID } = \%estructura ;
    }

    dump( %{ $ESTRUCTURAS{ A }{ MOTIVOS }{ a } } );

    ########################################
    # Procesar motivos
    # a partir de sus propiedades componer "notas"
    # combinado parametros (altura, duracion, dinamicas, etc)

    #my $this_tonica = %temp{ "tonica" } ? %temp{ "tonica" } : $tonica;
    #my $this_octava = %temp{ "octava" } ? %temp{ "octava" } : $octava;

    #my @this_escala;
    #if( %temp{ "alturas" } ){
    #    @this_escala = map {
    #        eval $_ # así soporta rangos en los yamls
    #    } @{ %temp{ "alturas" } };
    #} else {
    #    @this_escala = @escala;
    #}

    #my @this_alturas = map { 
    #    $_ + $this_tonica + ( 12 * $this_octava ) 
    #} @this_escala;

    ## my @this_duraciones = %temp{ "duraciones"} ? %temp{ "duraciones" } : @duraciones;
    ## my @this_dinamicas = %temp{ "dinamicas" }  ? %temp{ "dinamicas" } : @dinamicas;
    ## my $this_piso = %temp{ "piso" } ? %temp{ "piso" } : $piso;
    ## my $this_variacion = %temp{ "variacion" } ? %temp{ "variacion" } : $variacion;

    #########################################
    ## Procesasar y dwdefinir componentes 
    ## Componentes = "nota" del motivo combinancion entre: orden, altura, duración y dinámica)
    #my $n = 1;
    #my @temp_comps = ();
    #for( @{ %temp{ "progresion" } } ){
    #    my (
    #        $lector_altura, # posicion en las lista de alturas
    #        $transpo,
    #        #$repetir,
    #    ) = split;

    #     my $nota_altura = @this_alturas[ ( $lector_altura - 1 ) % @this_alturas  ] + $transpo;
    #     # add note repetition suport "while repetir...."

    #     #my $duracion   = $tic * @duraciones[ $index % $cantidad_duraciones ];
    #     #my $dinamica   = 127 * @dinamicas[ $index % $cantidad_dinamicas ];
    #     # add silense suport
    #     # my $compresion = $piso + rand ( $variacion );
    #     #
    #     #my $inicio = $retraso;
    #     #my $final  = $duracion;

    #     my $componente = { 
    #        indice   => $n,
    #        altura   => $nota_altura,
    #        duracion => 1,
    #        dinamica => .5,
    #     };
    #     push @temp_comps, $componente;
    #     $n++;
    #}


    # my %componentes; 
    # @componentes{ @temp_comps } = @temp_comps;
    # $motivos{ $motivo_ID}{"componentes"}= \%componentes; 


    ########################################
    # Secuenciar motivos ( array de motivos ) 
    # nota: Add super especial feture: control de  gap/overlap motivos
    # to do: agregar repticiones de secuencia

    # Track setup
    # my @events = (
    #     [ 'set_tempo', 0, $pulso ],
    #     [ 'text_event', 0, "Track: " . $nombre ], 
    #     [ 'patch_change', 0, $canal, $programa ], 
    # );

    # my $index = 0;
    # for(
    #     # reverse
    #     @{ $conf->{ secuencia_motivica } }
    #     # x $conf->{ repeticiones }
    # ){
    #     say ( $_ );
    #     my %notas = %{ %motivos{ $_ }->{ "componentes" } }; 

    #     # notas a MIDI::Events
    #     for my $nota ( keys %notas ){
    #         my $altura = %notas{ $nota }->{ "altura" };

    #         my $inicio = 0;
    #         my $final = $tic * %notas{ $nota }->{ "duracion" };

    #         my $dinamica = 127 * %notas{ $nota }->{ "dinamica" } ;
    #         my $fluctuacion = ( 1 - %notas{ $nota }->{ "variacion" } ) + rand( $variacion );

    #         push @events, (
    #               [ 'note_on' , $inicio, $canal, $altura, $dinamica * $fluctuacion],
    #               [ 'note_off', $final,  $canal, $altura, 0 ]
    #         );
    #         $index++;
    #     }

    # }


    # print Dumper( @events);
#     my $track = MIDI::Track->new({
#         'events' => \@events
#     });
#
#     push @tracks, $track;
#
}

#
# my $opus = MIDI::Opus->new({
#     'format' => 1, 
#     'ticks' => $tic,
#     'tracks' => \@tracks 
# });
# 
# $opus->write_to_file( 'output/secuencia.mid' );


__DATA__

pruebas:
 uno:
  elemento1: 123123
  elemento2: 222222
 dos:
  elemento1: 333333
  elemento2: 44444

for my $m ( keys
    %{ $config_file->{ pruebas } }
){
    dump($m);
    dump( $config_file->{ pruebas }{$m} )
}
