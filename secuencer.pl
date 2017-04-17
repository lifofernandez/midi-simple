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

    # Propiedades generales que heredan tods los motivos
    # pueden ser sobreescritas en cada uno de ellos
    # TODO: generar aca lista defactos independientes del config por si acaso
    my %defactos  = prosesar_sets( \%{ $config_file->{ defactos } });

    my $canal = $defactos{ canal };
    my $programa = $defactos{ programa };

    ########################################
    # Cargar Estructuras > Motivos

    my %ESTRUCTURAS = ();
    for my $estructuraID(
        keys %{ $config_file->{ ESTRUCTURAS } }
    ){
        my %estructura = %{ $config_file->{ ESTRUCTURAS }{ $estructuraID } };
        say "estructura: " . $estructuraID;

        my %MOTIVOS = ();
        for my $motivoID(
            sort
            keys %{ $estructura{ MOTIVOS } }
        ){
            say "  motivo: " . $motivoID;

            my %motivo = prosesar_sets( \%{ $estructura{ MOTIVOS }{ $motivoID } } );

            # Motivos que heredan propiedades de otros
            # a^, a^^, a^^^, etc
            my $padreID = $motivoID;
            my $prima = chop( $padreID );
            if( $prima eq "^" ){
                 my %motivo_padre = %{ $MOTIVOS{ $padreID } };
                 for my $prop_padre(
                     keys %motivo_padre
                 ){
                    if ( !$motivo{ $prop_padre } ){
                        my $valor_padre = $motivo_padre{ $prop_padre };
                        $motivo{ $prop_padre } = $valor_padre;
                    }
               }
            }
            # Negociar config defactos con las propias 
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
            # a partir de multipes propiedades componer secunecia
            # combinado parametros ( altura, duracion, dinamicas, etc )

            my @alturas = map {
                  $_ +
                  $motivo{ alturas }{ tonica } +
                  ( 12 * $motivo{ alturas }{ octava } )
            } @{ $motivo{ alturas }{ procesas } };
            my @duraciones =  @{ $motivo{ duraciones }{ procesas } };
            my @dinamicas  =  @{ $motivo{ dinamicas }{ procesas } };

            my $indice = 0;
            my @COMPONENTES = ();

            for( @{ $motivo{ microforma } } ){
               my $cabezal   = $_ - 1; # posicion en las lista de alturas

               # AGREGANDO SOPORTE PARA VOCES ACA
               #for( @{ $motivo{ voces }{ procesas }} ){
               #     my $voz = $_; # corrimiento del cabezal de la voz en cuestion
               #     $cabezal += $voz; # posicion en las lista de alturas

                    my $altura    = @alturas[ ( $cabezal ) % scalar @alturas ];

                    my $duracion  = @duraciones[ $indice % scalar @duraciones ];
                    #my $inicio = $tic * $retraso;
                    #my $final  = $duracion;

                    my $dinamica   = @dinamicas[ $indice % scalar @dinamicas ];

                    my $componente = {
                       indice   => $indice,
                       altura   => $altura,

                       duracion => $duracion,

                       dinamica => $dinamica,
                    };
                    push @COMPONENTES, $componente;
               #}
               $indice++;
            }

            # Paso ARRAY de HASH
            my %temp_comps; 
            @temp_comps{ @COMPONENTES } = @COMPONENTES;
            $motivo{ componentes } = \%temp_comps;

            $MOTIVOS{ $motivoID } = \%motivo;
        }
        $estructura{ MOTIVOS } = \%MOTIVOS;
        $ESTRUCTURAS{ $estructuraID } = \%estructura;
    }

    # TESTS
    # print Dumper %{ $ESTRUCTURAS{ A }{ MOTIVOS }{ a }{ dinamicas} };
    # print Dumper @{ $ESTRUCTURAS{ A }{ MOTIVOS }{ a }{ voces }{procesas} };
    # print Dumper %{ $ESTRUCTURAS{ A }{ MOTIVOS }{ "a^" } };
    # print Dumper @{ $ESTRUCTURAS{ A }{ MOTIVOS }{ a }{ duraciones }{ procesas } };
    # print Dumper @{ $ESTRUCTURAS{ A }{ MOTIVOS }{ a }{ microforma } };
    # print Dumper @{ $ESTRUCTURAS{ A }{ forma } };
    # print Dumper %{ $ESTRUCTURAS{ A }{ MOTIVOS }{ a }{componentes } };
    # print Dumper @{ $constantes{ macroforma } };


    ########################################
    # SECUENCIAR 

    # Track setup
    my @events = (
        [ 'set_tempo', 0, $pulso ],
        [ 'text_event', 0, "Track: " . $nombre ],
        [ 'patch_change', 0, $canal, $programa ],
    );

    # my $index = 0;
    for(
        # reverse
        ( @{ $constantes{ macroforma } } )
        x $constantes{ repeticiones }
    ){
          say $_ ;
          my %E =  %{ $ESTRUCTURAS{ $_ } };
          for(
              # reverse
              @{ $E{ forma } }
          ){
             say ' '.$_;
             my %M =  %{ $E{ MOTIVOS }{ $_ } };
             my %NOTAS =  %{ $M{ componentes } };

             # TODO: si agrego lista de defactos indpendiente del config evito esto
             my $orden =   $M{ orden } // 'indice';

             # NOTAS a MIDI::Events
             print ' -';
             for my $nota (
                 sort { $NOTAS{$a}{$orden} <=> $NOTAS{$b}{$orden} } 
                 keys %NOTAS
             ){
                 my $altura = $NOTAS{ $nota }{ altura };
                 print ' '. $NOTAS{$nota}{ indice };

                 # TODO: agregar retraso y recorte
                 my $inicio = 0;
                 my $final = $tic * $NOTAS{ $nota }{ duracion };

                 my $fluctuacion =  $M{ dinamicas }{ fluctuacion };
                 my $rand = 0;
                 if ( $fluctuacion ){
                     my $min  = -$fluctuacion;
                     my $max  = $fluctuacion;
                     $rand = $min + rand( $max - $min );
                 }

                 my $dinamica = int( 127 * ( $NOTAS{ $nota }{ dinamica } + $rand ) );

                 push @events, (
                     [ 'note_on' , $inicio, $canal, $altura, $dinamica ],
                     [ 'note_off', $final,  $canal, $altura, 0 ]
                 );
              }
              say ' -';
        }

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
$opus->write_to_file( 'output/secuencia.mid' );

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
