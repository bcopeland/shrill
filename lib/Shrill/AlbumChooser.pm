#! /usr/bin/perl

package Shrill::AlbumChooser;

use Shrill::Utility;

use strict;

our ($rows, $cols);

sub new
{
    my $this = shift;
    my ($config, $gladexml, $backend, $choose_album_cb) = @_;
    my $class = ref($this) || $this;
    my $self = {
        config => $config,
        gladexml => $gladexml,
        backend => $backend,
        choose_album_cb => $choose_album_cb,
        handlers => [],
    };
    bless $self, $class;

    $rows = $config->{'chooser_rows'};
    $cols = $config->{'chooser_cols'};

    $self->init();

    return $self;
}

sub init
{
    my $self = shift;
    my $backend = $self->{'backend'};
    my $glade = $self->{'gladexml'};

    $self->create_buttons;
    # $self->load_album_images(0);
    $backend->add_observer($self);

    my $playing_title = $glade->get_widget("atitle");
    $playing_title->set_text('');
}

#
# Create the appropriate number of buttons for the table
#
sub create_buttons
{
    my $self = shift;
    my $gladexml = $self->{'gladexml'};
    my $config = $self->{'config'};
    my $table = $gladexml->get_widget('table1');

    my $rows = $config->{'chooser_rows'};
    my $cols = $config->{'chooser_cols'};

    $table->resize($rows,$cols);

    foreach my $child ($table->get_children)
    {
        $table->remove($child);
    }

    foreach my $i (0..($rows*$cols-1))
    {
        my $button = Gtk2::Button->new();

        push @{ $self->{'buttons'} }, $button;

        my $row = int($i / $cols);
        my $col = int($i % $cols);

        $table->attach_defaults($button, $col, $col+1, $row, $row+1);

        # the button may get events even if we are on a different tab
        # when pushing keys, so realize it at create time.
        $button->realize();
        $button->show_all();
        my %hash = ();
        @{ $self->{'handlers'} }[$i] = \%hash;
    }

    # first time we are mapped, add the images
    my $id;
    $id = @{ $self->{'buttons'} }[0]->signal_connect('map-event',
        sub { 
           $self->load_album_images(0); 
           @{ $self->{'buttons'} }[0]->signal_handler_disconnect($id);
        });

    @{ $self->{'buttons'} }[0]->grab_focus;
}

sub load_album_images
{
    my ($self, $start) = @_;
    my $backend = $self->{'backend'};

    my $gladexml = $self->{'gladexml'};
    
    foreach my $i (0..($rows*$cols-1))
    {
        my $button = @{ $self->{'buttons'} }[$i];
        if (defined($button->get_child))
        {
            $button->remove($button->get_child);
        }

        my $album = @{ $backend->{'albums'} }[$start + $i];
        if (!defined($album))
        {
            # no more albums, set rest of buttons blank and insensitive
            $button->set_sensitive(0);
            next;
        }
        $button->set_sensitive(1);

        my $ifile = $backend->{'music_base'} . "/" .  $album->{'image_path'};

        if (!defined($album->{'image_path'}) || !(-e $ifile))
        {
            $ifile = $self->{'config'}->{'broken_image_file'};
        }

        my $image;
        eval
        {
            $image = Shrill::Utility::scale_image_to_allocation($ifile, 
                $button->allocation);
        };
        if ($@) 
        {
            # GDK can barf on paths with high ascii characters here
            $ifile = $self->{'config'}->{'broken_image_file'};
            $image = Shrill::Utility::scale_image_to_allocation($ifile, 
                $button->allocation);
        }

        if (defined($image)) { $button->add($image); }

        # redo sig handlers
        my $old_activate = @{ $self->{'handlers'} }[$i]->{'activate'};
        my $old_focus = @{ $self->{'handlers'} }[$i]->{'focus'};

        if (defined($old_activate))
        {
            $button->signal_handler_disconnect($old_activate);
        }
        if (defined($old_focus))
        {
            $button->signal_handler_disconnect($old_focus);
        }
        
        my $activate = $button->signal_connect( 'activate' => 
            $self->{'choose_album_cb'}, $album );
        my $focus = $button->signal_connect( 'focus' => 
            sub { $self->show_focus_title($album); });

        @{ $self->{'handlers'} }[$i]->{'activate'} = $activate;
        @{ $self->{'handlers'} }[$i]->{'focus'} = $focus;

        if ($i == 0)
        {
            $button->grab_focus;
            $self->show_focus_title($album); 
        }
        $button->show_all;
    }
}

sub show_focus_title
{
    my ($self, $album) = @_;
    my $glade = $self->{'gladexml'};
    my $text = "<b>" . 
       Shrill::Utility::escape_xml($album->{'album'}) . "</b> - " . 
       Shrill::Utility::escape_xml($album->{'artist'});
    my $focus_title = $glade->get_widget("focus_title");
    $focus_title->set_markup($text);
}

sub show_track_title
{
    my ($self, $track) = @_;
    my $glade = $self->{'gladexml'};
    my $text = "Now Playing: " . $track->{'artist'} . " - " . $track->{'title'};
    my $playing_title = $glade->get_widget("atitle");
    $playing_title->set_text($text);
}

sub notify_track_changed
{
    my ($self,$album,$track) = @_;
    $self->show_track_title($track);
}

sub notify_queue_changed
{
}

sub notify_track_stopped
{
}

1;
__END__
=head1 NAME

AlbumChooser - Shrill module for displaying album chooser

=head1 SYNOPSIS

use AlbumChooser;

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
