#!/usr/bin/env perl

########################################
# Secuenciador Motivocentrico 

# Lisandro Fernández ( Febrero 2017 )

use feature 'say';
use strict;
#use Data::Dump qw( dump );
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
    my %defaults = eval_ops( \%{ $config_file->{ global } });
   # print Dumper( $defaults{ alturas } );


    # Track setup

    my $nombre = $defaults{ nombre };
    say $nombre;
    my $canal = $defaults{ canal };
    my $programa = $defaults{ programa };

    ########################################
    # Cargar Estructuras Motivos
    # agregar config generales al motivo

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
            my %motivo = eval_ops( \%{ $estructura{ MOTIVOS }{ $mID } } );

            for my $prop_global(
                keys %defaults
            ){
                if ( !$motivo{ $prop_global } ){
                    my $valor_global = $defaults{ $prop_global };
                    $motivo{ $prop_global } = $valor_global;
                }
            }

            ########################################
            # Procesar motivos
            # a partir de sus propiedades componer "notas"
            # combinado parametros (altura, duracion, dinamicas, etc)
            my @alturas = map {
                 $_ + $motivo{ tonica } + ( 12 * $motivo{ octava }  )
            }  @{ $motivo{ alturas } };

            $MOTIVOS{ $mID } = \%motivo;
        }
        $estructura{ MOTIVOS } = \%MOTIVOS;

        $ESTRUCTURAS{ $eID } = \%estructura ;
    }

    #TEST
    #dump( %{ $ESTRUCTURAS{ A }{ MOTIVOS }{ a } } );



    #########################################
    # Procesasar y dwdefinir componentes

    # my $n = 1;
    # my @temp_comps = ();
    # for( @{ %temp{ "progresion" } } ){
    #    my (
    #        $lector_altura, # posicion en las lista de alturas
    #    ) = split;

    #    my $nota_altura = @this_alturas[ ( $lector_altura - 1 ) % @this_alturas ];

    #    #my $duracion   = $tic * @duraciones[ $index % $cantidad_duraciones ];
    #    #my $dinamica   = 127 * @dinamicas[ $index % $cantidad_dinamicas ];
    #    # add silense suport
    #    # my $compresion = $piso + rand ( $variacion );
    #    #
    #    #my $inicio = $retraso;
    #    #my $final  = $duracion;

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

# SUBS

# Evaluar Operadores de Perl en Hashes
sub eval_ops{
    my $H = shift;
    for my $v( keys %{ $H } ){
        if( ref( $H->{ $v } ) eq 'ARRAY'){ 
            my @array_evaluado = map {
               eval $_ 
            } @{ $H->{ $v } };
            $H->{ $v } = \@array_evaluado;
        }
    }
    return %{$H};
}

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
