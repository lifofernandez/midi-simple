#!/usr/bin/env perl

########################################
# Secuenciador Motivocentrico 
# Lisandro Fernández ( Febrero 2017 )

use feature 'say';
use strict;
use warnings;
use Pod::Usage;
use Getopt::Long;
use MIDI;
use YAML::XS 'LoadFile';
use POSIX qw( log10 );
use Data::Dumper;

########################################
# ARGUMENTS
my $version = '0.01.00';
my $site    = 'http://www.github.com/lifofernandez';
my (
    $salida,
    $help,
    $verbose,
    $man,
    $info
);
my $bpm = '60';
my @entradas = ();
GetOptions(
    'entradas=s' => \@entradas,
    'salida=s'   => \$salida, 
    'bpm=i'      => \$bpm, 

    'verbose+'   => \$verbose, 
    'help!'      => \$help, 
    'man!'       => \$man,
    'info!'      => \$info,
);
# pod2usage(-verbose => 1) && exit if ($opt_debug !~ /^[01]$/);
pod2usage( -verbose => 1 ) && exit if defined $help;
pod2usage( -verbose => 2 ) && exit if defined $man;

########################################
# CONSTANTES
my $tic = 240; 
my $pulso = int( ( 60 / $bpm ) * 1000 ) . '_000';
my $simbolo_prima = "^";

########################################
# PREPROCESO DE ELEMENTOS
my @CONFIGS = ();
for( @entradas ){
    if( -f $_ ){
      push @CONFIGS, $_;
    }
    if( -d $_ ){
      my @dir = <./$_/*>;
      push @CONFIGS, @dir;
    }
}

my @tracks;
for( @CONFIGS ){
    my $config_file = LoadFile( $_ );
    my %constantes = %{ $config_file->{ constantes } };
    my $metro = $constantes{ metro } // '4/4';
    my (
        $numerador,
        $denominador,
    ) = split '/', $metro;
    # rpm.pbone.net/index.php3/stat/45/idpl/2395553/numer/3/nazwa/MIDI::Filespec
    # Time Signature event
    # The denominator is a negative power of two: log10( X ) / log10( 2 ) 
    # 2 represents a quarter-note, 3 represents an eighth-note, etc.
    $denominador = log10( $denominador ) / log10( 2 );

    # Track setup
    my $nombre = $constantes{ nombre };
    say "\n" . "#" x 80 if $verbose;
    say "TRACK: ".$nombre;
    # Propiedades generales que heredan todos los motivos
    # y que pueden ser sobreescritas en c/u.
    my %defacto  = prosesar_sets( \%{ $config_file->{ defacto } } );
    my $canal = $defacto{ canal };
    say "CANAL: ".$canal if $verbose;
    my $programa = $defacto{ programa };
    say "PROGRAMA: ".$programa if $verbose;
    my @macroforma = @{ $constantes{ macroforma } };
    @macroforma = reverse @macroforma if $constantes{ revertir };
    print "MACROFORMA: " if $verbose;
    print  "@macroforma\n" if $verbose;
    my $repetir = $constantes{ repetir } // 1;
    say "repetir: " . $repetir if $verbose;

    ########################################
    # Preparar Estructuras > Motivos > Componentes
    my %ESTRUCTURAS = %{ $config_file->{ ESTRUCTURAS } };
    for my $estructuraID(
        sort
        keys %ESTRUCTURAS 
    ){
        print "\n";
        say "ESTRUCTURA: " . $estructuraID if $verbose;
        my %estructura = %{ $ESTRUCTURAS{ $estructuraID } };
        # Estructuras que heredan propiedades de otros
        # A^^ hereda de A^ que hereda de A.
        my $madreID = $estructuraID;
        my $prima = chop( $madreID );
        if( $prima eq $simbolo_prima ){
             my %prima = %{ $ESTRUCTURAS{ $madreID } };
             %estructura = heredar( \%prima, \%estructura);
        }
        print "  FORMA: " if $verbose;
        print "@{ $estructura{ forma } }\n" if $verbose;

        my %MOTIVOS = ();
        for my $motivoID(
            sort
            keys %{ $estructura{ MOTIVOS } }
        ){
            say "  MOTIVO: " . $motivoID if $verbose;
            #TODO posible BUG, esto deberia estar despues de sucesion
            my %motivo = %{ $estructura{ MOTIVOS }{ $motivoID } };
            # Motivos que heredan propiedades de otros
            # a^^ hereda de a^ que hereda de a.
            my $padreID = $motivoID;
            my $primo = chop( $padreID );
            if( $primo eq $simbolo_prima ){
                 my %primo = %{ $MOTIVOS{ $padreID } };
                 %motivo = heredar( \%primo, \%motivo );
            }
            # Carga configuraciones generales 
            %motivo = heredar( \%defacto, \%motivo );
            # Custos set preproceso
            %motivo = prosesar_sets( \%motivo );
            ########################################
            # Procesar motivos armar componetes
            # combinado parametros ( altura, duracion, dinamicas, etc )
            my @alturas = map {
                  $_ +
                  $motivo{ alturas }{ tonica } +
                  ( 12 * $motivo{ alturas }{ octava } )
            } @{ $motivo{ alturas }{ procesas } };
            print "   ALTURAS: " if $verbose;
            print "@alturas\n" if $verbose;
            my @microforma =  @{ $motivo{ microforma } } ;
            @microforma = reverse @microforma if $motivo{ revertir };
            my $repetir_motivo =   $motivo{ repetir } // 1;
            print "   MICROFORMA: " if $verbose;
            print "@microforma\n" if $verbose;
            print "   ORDENADOR: " . $motivo{ ordenador }. "\n" if $verbose;
            my @duraciones = @{ $motivo{ duraciones }{ procesas } };
            my @dinamicas  = @{ $motivo{ dinamicas }{ procesas } };
            my $indice = 0;
            my @COMPONENTES = ();
            say "   COMPONENTES" if $verbose;
            for( ( @microforma ) x $repetir_motivo ){
               # posicion en set de alturas
               my $cabezal = $_ - 1; 
               # No usar 0 como primer posicion del set esta justificada
               # a la necesidad de reservar un elemento para representar  
               # el silencio
               # TODO Revisar ordenador 'alturas' y  propiedad altura de los componentes
               my $altura = @alturas[ ( $cabezal ) % scalar @alturas ];
               my $nota_st = '';
               my @VOCES = ();

               for( @{ $motivo{ voces }{ procesas } } ){
                    #TODO reconsiderar si usar o no voz relacion = 0 para la 
                    if ( $_ ne 0 ){
                        # posicion en en set de alturas para la esta voz 
                        my $cabezal_voz = ( $cabezal + $_ ) - 1;
                        my $voz = @alturas[ $cabezal_voz % scalar @alturas ];
                        push @VOCES, $voz;
                        $nota_st  = $nota_st . $voz  . " ";
                    }
               }
               my $voces_st =  "ALTURAS: " . $nota_st;
               my $duracion  = @duraciones[ $indice % scalar @duraciones ];
               my $dinamica  = @dinamicas[ $indice % scalar @dinamicas ];
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
               print "\tDINAMICA: " . int( $dinamica * 127 ) if $verbose;
               print "\t" . $voces_st  if $verbose;
               print "\tDURACION: " . $duracion . "qn" if $verbose;
               print "\n" if $verbose;
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
        [ 'set_tempo', 0, $pulso ],
        [ 'time_signature', 0, $numerador, $denominador, 24, 8],
        [ 'text_event', 0, "TRACK: " . $nombre ],
        [ 'patch_change', 0, $canal, $programa ],
    );
    my $momento = 0;
    for( ( @macroforma ) x $repetir ){
          my %E =  %{ $ESTRUCTURAS{ $_ } };

          my @forma = @{ $E{ forma } };
          my $repetir_estructura = $E{ repetir } // 1;
          @forma = reverse @forma if $E{ revertir };
          for( ( @forma ) x $repetir_estructura ){
             my %M =  %{ $E{ MOTIVOS }{ $_ } };
             my %C =  %{ $M{ COMPONENTES } };
             my $orden = $M{ ordenador } // 'indice';
             my $retraso =  int( $tic * ( $M{ duraciones }{ retraso } // 0 ) );
             my $recorte =  int( $tic * ( $M{ duraciones }{ recorte } // 0 ) );
             my $fluctuacion = $M{ dinamicas }{ fluctuacion };
             my @compIDs = grep defined $C{ $_ }{ $orden }, keys %C;
             for my $componenteID (
                 sort { $C{ $a }{ $orden } <=> $C{ $b }{ $orden } } 
                 @compIDs # keys %C
             ){
                 my $final = $tic * $C{ $componenteID }{ duracion };
                 my @V = @{ $C{ $componenteID }{ voces } };
                 # Sin Voces = SILENCIO
                 if ( !@V ){
                     $momento = $momento + $final;
                     next;
                 }
                 $momento = $momento + $retraso; 
                 $final = $final - $recorte - $retraso;
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
                         [ 'note_on' , $momento, $canal, $altura, $dinamica ],
                     );
                     $momento = 0;
                 }
                 $momento = $momento + $recorte; 
                 for( @V ){
                     my $altura = $_;
                     push @events, (
                         [ 'note_off', $final,  $canal, $altura, 0 ],
                     );
                     $final = 0;
                 }
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
# Reecorre 1 HASH, evalua custom sets y arrays regulares
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
            my $reverse = $H->{ $v }{ revertir } // 0;
            @array_procesado = reverse @array_procesado if $reverse;
            $H->{ $v }{ procesas } = \@array_procesado;
        }
        # microforma range suport
        if( ref( $H->{ $v } ) eq 'ARRAY'){ 
            my @array_evaluado = map {
               eval $_
            } @{ $H->{ $v } };
            $H->{ $v } = \@array_evaluado;
        }
    }
    return %{ $H };
}

# Pasar propiedades faltantes de %Ha > %Hb 
sub heredar{
    my( $padre, $hijo ) = @_;
    my $c = 1;
    for my $propiedad(
        keys %{ $padre }
    ){
        if( !$hijo->{ $propiedad } ){
             $hijo->{ $propiedad } = $padre->{ $propiedad };
        }elsif(
            ( ref( $hijo->{ $propiedad } ) eq 'HASH' ) &&
            ( $propiedad ne "COMPONENTES" ) 
        ){
            my %nieto = heredar( 
                 \%{ $padre->{ $propiedad } },
                 \%{ $hijo->{ $propiedad } }
            );
            $hijo->{ $propiedad } = \%nieto; 
        }
    }
    return %{ $hijo } 
}



END{
  if( defined $info ){
    print
      "\nModules, Perl, OS, Program info:\n",
      "  Pod::Usage            $Pod::Usage::VERSION\n",
      "  Getopt::Long          $Getopt::Long::VERSION\n",
      "  MIDI                  $MIDI::VERSION\n",
      "  YAML::XS              $YAML::XS::VERSION\n",
      "  POSIX                 $POSIX::VERSION \n",
      "  strict                $strict::VERSION\n",
      "  Perl                  $]\n",
      "  OS                    $^O\n",
      "  secuenciador.pl       $version\n",
      "  $0\n",
      "  $site\n",
      "\n\n";
  }
}


=head1 NAME

 secuenciador.pl

=head1 SYNOPSIS

 Generar secuencia MIDI a partir de multiples hojas de analisis 
 serializadas en sintaxis YAML. 

 NOTA:
 Tanto el codigo, como tambien esta documentacion, esta escrito lo maximo 
 posible en espaniol (se presinde de carateres latinos) para en un 
 principio favorecer y atraer a usuarios que no leen ingles.
 No se descarta la posibilidad de futuras traducciones.


=head1 DESCRIPTION


 Cada track MIDI es representado por una hoja de analisis con las 
 configuraciones necesarias para obtener una progresion musical.

 La organizacion interna de estas configuraciones de track trata de 
 ser lo mas autodescriptiva posible y representar una hoja de analisis 
 musical jerarquizada en Estrcucturas que continenen Motivos.
 A su vez, intenta acercarse a la flexibilidad caracteristica del entorno de
 programacion Perl y su ecosistema.

 Los Motivos heredan propiedades de configuraciones generales
 (defacto) asi como tambien de otros motivos "primos".

 Todos los Sets (alturas, duraciones, dinamicas, etc) soportan rangos 
 y operaciones matematicas (necesita explicacion).

 Un ejemplo de configuracion de track mininma puede ser algo como esto:

 ########################################
 # Cofiguraciones generales del Track
 constantes:
   nombre       : Feliz Cumpleanios,  melodia
   metro        : 9/8
   macroforma   : [ A ]
   repetir : 1
 
 ########################################
 # Cofiguraciones Generales 
 defacto:
   canal      : 1 
   programa   : 1
   ordenador  : indice
   alturas:
     set         : [ 0, 2, 4, 5, 7, 9, 11,
                    12, 2+12, 4+12, 5+12, 7+12, 9+12, 11+12 ] # Diatonica Mayor 
     octava      : 0  
     tonica      : 60 # C central
   voces:
     set         : [ 1 ] 
   duraciones:
     set         : [ 1,.5,(1.5)x2 ]
   dinamicas:
     set         : [ .8 ] 
     fluctuacion : .1
 
 ESTRUCTURAS:
   A:
     forma: [ a, b, a, b^, a^, a^^, a^^^, b^ ]
     MOTIVOS:
       a:
         microforma : [ 5, 5, 6, 5 ]
       a^:
         microforma : [ 5, 5, 12, 10 ]
       a^^:
         microforma : [ 8, 8, 7, 6 ]
       a^^^:
         microforma : [ 11, 11, 10, 8 ]
       b:
         duraciones:
           set        : [ 1.5, 3 ]
         microforma : [ 8, 7 ]
       b^:
         microforma : [ 9, 8 ]

 Esta no es la unica manera de represantar la misma melodia y 
 existen mas opciones diponibles que a las expuestas.

 Mas inforamcion en los ejemplos.


=head1 ARGUMENTS

 --entradas   Multiples Tracks en formato YAML acepta archivos o carpetas.
 --salida     Archivo .mid a generar.
 --bpm        Pulsos por minuto para la secuencia.
 --help       Imprime esta ayuda en vez de generar secuencia MIDI.
 --man        Imprime la pagina man completa en vez de generar MIDI.

 Los argumentos pueden declararse tanto en forma larga como corta.
 Por ejemplo:
   secuenciador.pl --entradas ejemplos
   secuenciador.pl -e ejemplos -e feliz_cumpleanios/melodia.yml

=head1 OPTIONS

 --info       Informacion sobre, modulos, entorno y programa.
 --verbose    Expone los elementos musicales previamente a secuenciarlos. 

=head1 FEATURES

=head2 Herencia

  Estructuras y Motivos pueden compartir propiedades vinculandose mediante 
  el simbolo "^" final del nombre d ela estructura

=head2 Repetir

 Todas las listas de elemenots formales (Macroforma, Forma y Microforma) pueden
 ser repetidas N veces segun el el valor declarado en la propiedad "repetir".

=head2 Revertir

 Todos los Sets listas de elementos formales pueden ser revertidos  
 con la propiedad "revertir" con valor true  

=head2 Custom Sets

 Explicar preprocesos realizados sobre los set, mapeo de valores y uso de diferentes math ops

=head1 AUTHOR

 Lisandro Fernandez

=head1 CREDITS


=head1 TESTED

 Pod::Usage            1.68
 Getopt::Long          2.48
 MIDI                  0.83
 YAML::XS              0.63
 POSIX                 1.65 
 strict                1.11
 Perl                  5.024001
 OS                    linux & darwin
 secuenciador.pl       0.00.01

=head1 BUGS

 tempo/bpm problem...
 REVISAR, herencia entre Estructuras.

=head1 TODO
 revisar linea 123
 Agregar soporte para metro, chanel, program change entre MOTIVOS
 Revisar ordenador 'alturas' y  propiedad altura de los componentes
 Control de superposicion o separacion entre Estructuras, Motivos y Componentes.
 Lista defacto general para todos los tracks/configs.
 Terminar esta documnetacion.
 Test on ActivePerl
 Agregar informacion de debbugeo en errores

=head1 UPDATES

 2017-04-23   12:00 GTM+3
   Feliz Cumpleanios Complete; es capaz de genrar esta melodia
   a partir de la hoja de analisis.

=cut
