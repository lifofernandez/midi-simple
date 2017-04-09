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
    my %constantes = %{ $config_file->{ constantes } };

    # Track setup

    my $nombre = $constantes{ nombre };
    say $nombre;

    my %defactos  = prosesar_sets( \%{ $config_file->{ defactos } });

    my $canal = $defactos{ canal };
    my $programa = $defactos{ programa };

    ########################################
    # Cargar Estructuras Motivos
    # agregar config defactos al motivo

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
            my %motivo = prosesar_sets( \%{ $estructura{ MOTIVOS }{ $mID } } );

            for my $prop_global(
                keys %defactos
            ){
                if ( !$motivo{ $prop_global } ){
                    my $valor_global = $defactos{ $prop_global };
                    $motivo{ $prop_global } = $valor_global;
                }
            }

            ########################################
            # Procesar motivos armar componetes
            # a partir de sus propiedades componer "NOTAS"
            # combinado parametros (altura, duracion, dinamicas, etc)
            my @alturas = map {
                  $_ +
                  $motivo{ alturas }{ tonica } +
                  ( 12 * $motivo{ alturas }{ octava } )
            } @{ $motivo{ alturas }{ procesas } };
            my @duraciones =  @{ $motivo{ duraciones }{ procesas } };
            my @dinamicas =  @{ $motivo{ dinamicas }{ procesas } };

            #########################################
            # Combinar propiedades del motivo en  componentes

            my $indice = 0;
            my @COMPONENTES = ();
            for( @{ $motivo{ microforma } } ){
               my (
                   $cabezal, # posicion en las lista de alturas
               ) = split;

               my $cabezal = $_; # posicion en las lista de alturas
               my $altura = @alturas[ ( $cabezal - 1 ) % @alturas ];

               my $duracion   = $tic * @duraciones[ $cabezal % @duraciones ];
               #my $inicio = $tic * $retraso;
               #my $final  = $duracion;

               # ACA DEFINR EL RAND apartir del valor relativo (0-1) ACA
               # PERO APLICARLO DESPUES en la secuencia
               # my $compresion = $piso + rand ( $variacion );
               my $dinamica   = 127 * @dinamicas[ $cabezal % @dinamicas ];

               my $componente = {
                  indice   => $indice,
                  altura   => $altura,
                  duracion => $duracion,
                  dinamica => $dinamica,
               };
               push @COMPONENTES, $componente;
               $indice++;
            }


            # Paso ARRAY de HASH
            my %temp_comps; 
            @temp_comps{ @COMPONENTES } = @COMPONENTES;

            $motivo{ componentes } = \%temp_comps;

            $MOTIVOS{ $mID } = \%motivo;
        }
        $estructura{ MOTIVOS } = \%MOTIVOS;

        $ESTRUCTURAS{ $eID } = \%estructura;
    }

    # TESTS
    # print  Dumper %{ $ESTRUCTURAS{ A }{ MOTIVOS }{ a }{ dinamicas} } ;
    # print  Dumper @{ $ESTRUCTURAS{ A }{ MOTIVOS }{ a }{ microforma } } ;
    # print  Dumper @{ $ESTRUCTURAS{ A }{ forma } } ;
    # print  Dumper %{ $ESTRUCTURAS{ A }{ MOTIVOS }{ a }{componentes } } ;






    # print Dumper( @{ $constantes{ macroforma } } );
    ########################################
    # Secuenciar motivos ( array de motivos )
    # nota: Add super especial feture: control de  gap/overlap motivos
    # to do: agregar repticiones de secuencia

    # Track setup
     my @events = (
         [ 'set_tempo', 0, $pulso ],
         [ 'text_event', 0, "Track: " . $nombre ],
         [ 'patch_change', 0, $canal, $programa ],
     );

    # my $index = 0;
    for(
        # reverse
        @{ $constantes{ macroforma } }
        # x $constantes->{ repeticiones }
    ){
          say $_ ;
          my %E =  %{ $ESTRUCTURAS{ $_ } };
          for(
              # reverse
              @{ $E{ forma } }
              #x $E{ repeticiones }
          ){
             say ' '.$_;
             # my %M =  %{ $E{MOTIVOS}{ $_ } };
             my %NOTAS =  %{ $E{ MOTIVOS }{ $_ }{ componentes } };

         # NOTAS a MIDI::Events
             for my $nota (
                 sort { $NOTAS{$a}{indice} <=> $NOTAS{$b}{indice} } 
                 keys %NOTAS
             ){
                 say '   '.$NOTAS{$nota}{indice};
                 #my $altura = %NOTAS{ $nota }->{ "altura" };

                 #my $inicio = 0;
                 #my $final = $tic * %NOTAS{ $nota }->{ "duracion" };

                 ##my $fluctuacion = ( 1 - %NOTAS{ $nota }->{ "variacion" } ) 
                 #      #   + rand( $variacion );
                 #my $dinamica = 127 * %NOTAS{ $nota }->{ "dinamica" } ;
                 ##APLICAR RANDOM pero definirlo antes

                 #push @events, (
                 #      [ 'note_on' , $inicio, $canal, $altura, $dinamica ],
                 #      [ 'note_off', $final,  $canal, $altura, 0 ]
                 #);
              }
        }

    }


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

# Procesar Sets (
# recorre 1 hash, evalua sets y arrays
sub prosesar_sets{
    my $H = shift;
    for my $v( keys %{ $H } ){
        if(
           ( ref( $H->{ $v } ) eq 'HASH' ) &&
           ( exists $H->{ $v }{ set } )
        ){
            my $grano = $H->{ $v }{ grano } ? $H->{ $v }{ grano } : 1;
            my $operador = $H->{ $v }{ operador } ?
                $H->{ $v }{ operador } : '*';

            my @array_evaluado = map {
               eval $_
            } @{ $H->{ $v }{ set } };
            my @array_procesado = map { 
               eval( $_ . $operador . $grano) 
            } @array_evaluado;
            $H->{ $v }{ procesas } = \@array_procesado;

        }
        if( ref( $H->{ $v } ) eq 'ARRAY'){ 
            my @array_evaluado = map {
               eval $_
            } @{ $H->{ $v } };
            # print ( @array_evaluado );
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
