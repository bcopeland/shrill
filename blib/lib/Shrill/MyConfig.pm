package Shrill::MyConfig;

use Carp;
use strict;

# share is overridden by configure
my $share = "/usr/share" . "/shrill";
my $doc = "/usr/share" . "/doc/shrill";
my $config_location = $ENV{'HOME'} . "/.shrill/config";

sub new
{
    # defaults
    my $self = {
        'mserv_server' => 'localhost',
        'mserv_port' => 4444,
        'mserv_user' => 'user',
        'mserv_pass' => 'pass',
        'mserv_meta_dir' => '/var/lib/mserv/.mservtrackinfo',
        'music_dir' => '/path/to/music',
        'fullscreen' => '1',
        'chooser_rows' => '2',
        'chooser_cols' => '3',
        'broken_image_file' => $share . '/noart.jpg',
        'gtkrc_file' => $share . '/shrill.gtkrc',
        'glade_file' => $share . '/shrill.glade',
        'play_on_start' => '0',
        'stop_on_exit' => '0',
        'debug' => '0',
        'key_prev_page' => 'Page_Up',
        'key_next_page' => 'Page_Down',
        'key_activate' => 'Return',
        'key_escape' => 'Escape',
        'key_play' => 'x',
        'key_next_track' => 'c',
        'key_stop' => 'v',
        'key_quit' => 'q',
    };
    bless $self;
    $self->check_config;
    $self->read_config;
    return $self;
}

sub check_config
{
    my $self = shift;

    if (!(-e $config_location))
    {
        $self->create_config;

        croak "$config_location does not exist.\n" .
              "Creating a new one.  You MUST edit it!\n". 
              "Exit";
    }
}

sub read_config
{
    my $self = shift;

    my $file;
    open($file, "$config_location");
    while(<$file>)
    {
        s/#.*//g;
        if (/^(\w*)\s*=\s*(.*)$/)
        {
            my ($key, $val) = ($1, $2);
            $val =~ s/\s*$//g;
            $self->{$key} = $val;
        }
    }
    close($file);
}

sub create_config
{
    my $self = shift;

    # mkdir -p
    my @path = split(/\//, $config_location);
    for (my $i=0; $i < @path-1; $i++) 
    {
        my $dir = "/" . join ("/", @path[0..$i]);
        if (!(-e $dir))
        {
            mkdir $dir || croak "Error opening directory: $*";
        }
    }

    my $file;

    open ($file, ">$config_location") || croak "Error writing config: $*";

    my $in;
    if (open ($in, "$doc/sample.config"))
    {
        # copy sample to local
        while (<$in>)
        {
            print $file $_;
        }
        close($in);
    }
    else
    {
        print $file "# Sample config not found.  Good luck!\n";

        # dump all the hash values
        print $file join ("\n", 
            map { $_ = "$_ = " . $self->{$_}; } keys %{$self});
    }
    close($file);

    chmod $config_location, 0600;
}

1;
__END__
=head1 NAME

MyConfig - Shrill module for configuration

=head1 SYNOPSIS

use MyConfig;

=head1 DESCRIPTION

This module is used internally by the Shrill program.

=head1 AUTHOR

Bob Copeland (email@bobcopeland.com)

=head1 COPYRIGHT

Copyright (C) 2005  Bob Copeland (email@bobcopeland.com)

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

=cut
