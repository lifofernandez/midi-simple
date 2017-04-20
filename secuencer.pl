#!/usr/bin/env perl

########################################
# Secuenciador Motivocentrico 

# Lisandro Fernández ( Febrero 2017 )

use feature 'say';
use strict;
use warnings;
use Getopt::Std;
use Data::Dumper;
use MIDI;
use YAML::XS 'LoadFile';

########################################
# ARGUMENTS
getopts('vi:o:p:');
our(
    $opt_v,
    $opt_i,
    $opt_o,
    $opt_p
);
my $verbose = $opt_v;
my $yamls = $opt_i // 'tracks';
my $salida  = $opt_o // 'sequencia.mid';
my $pulso = $opt_p // 1000; # mili

########################################
# CONSTANTES

my $tic = 240; 
my @configs = <./$yamls/*>;

my @tracks;
foreach ( @configs ){

    my $config_file = LoadFile( $_ );
    my %constantes = %{ $config_file->{ constantes } };

    # Track setup
    my $nombre = $constantes{ nombre };
    say "\n" . "#" x 80 if $verbose;
    say "TRACK: ".$nombre;

    # Propiedades generales que heredan todos los motivos
    # pueden ser sobreescritas en c/u-
    my %defacto  = prosesar_sets( \%{ $config_file->{ defacto } });
    # TODO: lista defacto general e para todos los tracks/configs

    my $canal = $defacto{ canal };
    say "CANAL: ".$canal if $verbose;

    my $programa = $defacto{ programa };
    say "PROGRAMA: ".$programa if $verbose;

    my @macroforma = @{ $constantes{ macroforma } };
    print "MACROFORMA: " if $verbose;
    print  "@macroforma\n" if $verbose;

    my $repeticiones = $constantes{ repeticiones };
    say "REPETICIONES: " . $repeticiones if $verbose;

    ########################################
    # Preparar Estructuras > Motivos > Componentes

    my %ESTRUCTURAS = ();
    for my $estructuraID(
        keys %{ $config_file->{ ESTRUCTURAS } }
    ){
        print "\n";
        say "ESTRUCTURA: " . $estructuraID if $verbose;
        my %estructura = %{ $config_file->{ ESTRUCTURAS }{ $estructuraID } };
        print "  FORMA: " if $verbose;
        print "@{ $estructura{ forma } }\n" if $verbose;

        my %MOTIVOS = ();
        for my $motivoID(
            sort
            keys %{ $estructura{ MOTIVOS } }
        ){
            say "  MOTIVO: " . $motivoID if $verbose;
            my %motivo = prosesar_sets( 
                \%{ $estructura{ MOTIVOS }{ $motivoID } } 
            );

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
            # Negociar config defacto con las propias 
            for my $prop_global(
                keys %defacto
            ){
                if ( !$motivo{ $prop_global } ){
                    my $valor_global = $defacto{ $prop_global };
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
            my @duraciones = @{ $motivo{ duraciones }{ procesas } };
            my @dinamicas  = @{ $motivo{ dinamicas }{ procesas } };

            print "   ALTURAS: " if $verbose;
            print "@alturas\n" if $verbose;

            my @microforma =  @{ $motivo{ microforma } } ;
            print "   MICROFORMA: " if $verbose;
            print "@microforma\n" if $verbose;

            print "   ORDENADOR: " .$motivo{ ordenador }."\n" if $verbose;


            my $indice = 0;
            my @COMPONENTES = ();
            say "   COMPONENTES" if $verbose;

            for( @microforma  ){

               my $cabezal = $_ - 1; # posicion en las lista de alturas
               my $altura = @alturas[ ( $cabezal ) % scalar @alturas ];

               my $nota_st = '';
               my @VOCES = ();
               for( 
                   @{ $motivo{ voces }{ procesas } } 
               ){
                    # pos. en las lista de alturas para la voz actual
                    my $cabezal_voz = $cabezal + $_;
                    my $voz = @alturas[ ( $cabezal_voz ) % scalar @alturas ];
                    push @VOCES, $voz;

                    $nota_st  = $nota_st . $voz  . " ";
               }
               my $voces_st=  "ALTURAS: " . $nota_st;

               my $duracion  = @duraciones[ $indice % scalar @duraciones ];
               my $dinamica   = @dinamicas[ $indice % scalar @dinamicas ];

               if ( $_ eq 0 ){
                   $altura = 0;
                   $dinamica = 0;
                   splice( @VOCES );
                   $voces_st=  "SILENCIO";
               }

               my $componente = {
                  indice   => $indice,
                  altura   => $altura,
                  voces    => \@VOCES,
                  duracion => $duracion,
                  dinamica => $dinamica,
               };
               push @COMPONENTES, $componente;
               $indice++;

               # verbosidad
               print "    " if $verbose;
               print "INDICE: " . $indice . " " if $verbose;
               print "\tCABEZAL: " . ( $cabezal + 1) . " " if $verbose;
               print "\tDURACION: " . $duracion . "qn" if $verbose;
               print "\tDINAMICA: " . int( $dinamica * 127 ) if $verbose;
               print "\t" . $voces_st . "\n" if $verbose;
            }

            # Paso AoH a HoH
            my %temp_comps; 
            @temp_comps{ @COMPONENTES } = @COMPONENTES;

            $motivo{ COMPONENTES } = \%temp_comps;

            $MOTIVOS{ $motivoID } = \%motivo;
        }
        $estructura{ MOTIVOS } = \%MOTIVOS;
        $ESTRUCTURAS{ $estructuraID } = \%estructura;
    }

    # TESTS
    # print Dumper %{ $ESTRUCTURAS{ A }{ MOTIVOS }{ a }{ dinamicas} };
    # print Dumper @{ $ESTRUCTURAS{ A }{ MOTIVOS }{ a }{ voces }{procesas} };
    # print Dumper %{ $ESTRUCTURAS{ A }{ MOTIVOS }{ "a^" } };
    # print Dumper @{ $ESTRUCTURAS{ A }{ MOTIVOS }{ a }{ microforma } };
    # print Dumper @{ $ESTRUCTURAS{ A }{ forma } };
    # print Dumper %{ $ESTRUCTURAS{ A }{ MOTIVOS }{ a }{componentes } };
    # print Dumper @{ $constantes{ macroforma } };


    ########################################
    # SECUENCIAR 

    # Track setup
    my @events = (
        [ 'set_tempo', 0, $pulso . '_000'],
        [ 'text_event', 0, "Track: " . $nombre ],
        [ 'patch_change', 0, $canal, $programa ],
    );

    # my $index = 0;
    for(
        # reverse
        ( @macroforma )
        x $repeticiones
    ){
          my %E =  %{ $ESTRUCTURAS{ $_ } };
          for(
              # reverse
              @{ $E{ forma } }
          ){
             my %M =  %{ $E{ MOTIVOS }{ $_ } };
             my %C =  %{ $M{ COMPONENTES } };

             my $orden = $M{ ordenador } // 'indice';

             # to avoid "Use uninitialized value..."
             my @compIDs = grep defined $C{ $_ }{ $orden }, keys %C;

             # Componentes a MIDI::Events
             my $inicio = 0;
             # TODO REVISAR INICIO/RETRASO cambio de motivo
             for my $componenteID (
                 sort { $C{ $a }{ $orden } <=> $C{ $b }{ $orden } } 
                 @compIDs # keys %C
             ){

                 my @V = @{ $C{ $componenteID }{ voces } };
                  

                 # TODO REVISAR INICIO/RETRASO cambio de motivo
                 my $final = $tic * $C{ $componenteID }{ duracion };
                 my $retraso =  $tic * $M{ duraciones }{ retraso } // 0;
                 my $recorte =  $tic * $M{ duraciones }{ recorte } // 0;

                 if ( 
                      !@V  
                 ){
                     # Sin Voces, SILENCIO
                     $inicio = $recorte + $final; 
                     next;
                 }

                 


                 $inicio = $inicio + $retraso; 
                 $final = $final - $recorte - $retraso;
                 my $fluctuacion = $M{ dinamicas }{ fluctuacion };
                 my $rand = 0;
                 if ( $fluctuacion ){
                     my $min  = -$fluctuacion;
                     my $max  = $fluctuacion;
                     $rand = $min + rand( $max - $min );
                 }

                 my $dinamica = int( 
                     127 * ( $C{ $componenteID }{ dinamica } + $rand ) 
                 );

                 for( @V ){
                     my $altura = $_;
                     push @events, (
                         [ 'note_on' , $inicio, $canal, $altura, $dinamica ],
                     );
                     $inicio = 0;
                 }
                 for( @V ){
                     my $altura = $_;
                     push @events, (
                         [ 'note_off', $final,  $canal, $altura, 0 ],
                     );
                     $final = 0;
                 }

                 $inicio = $inicio + $recorte; 
              }
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
$opus->write_to_file( $salida );

# SUBS

# Procesar Sets 
# recorre 1 HASH, evalua sets y arrays
sub prosesar_sets{
    my $H = shift;
    for my $v( keys %{ $H } ){
        if(
           ( ref( $H->{ $v } ) eq 'HASH' ) &&
           ( exists $H->{ $v }{ set } )
        ){
            my $grano = $H->{ $v }{ grano } // 1;
            my $operador = $H->{ $v }{ operador } // '*';

            my @array_evaluado = map {
               eval $_
            } @{ $H->{ $v }{ set } };
            my @array_procesado = map { 
               eval( $_ . $operador . $grano ) 
            } @array_evaluado;

            my $reverse = $H->{ $v }{ reverse } // 0;
            @array_procesado = reverse @array_procesado if $reverse;

            $H->{ $v }{ procesas } = \@array_procesado;

        }
        if( ref( $H->{ $v } ) eq 'ARRAY'){ 
            my @array_evaluado = map {
               eval $_
            } @{ $H->{ $v } };
            $H->{ $v } = \@array_evaluado;
        }

    }
    return %{ $H };
}

__DATA__
