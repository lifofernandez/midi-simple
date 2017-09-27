# sequenceciador.pl 

## Instalar Dependecias

```bash
sudo cpan i MIDI Pod::Usage
# Debian
sudo apt install perl-doc
```

## Secuenciar MIDI 

```bash
./secuenciador.pl -i ejemplos/feliz/melodia.yml -o ARCHIVO.mid
```

## Reporducir MIDI 

```bash
sudo pacman -S fluydsynth soundfont-fluid
./midi_play ARCHIVO.mid
```

