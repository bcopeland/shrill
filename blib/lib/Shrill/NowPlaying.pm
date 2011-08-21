#
#  Screen that displays the album and track that is currently playing,
#  along with the next couple in the queue.
#
package Shrill::NowPlaying;

use Shrill::Utility;
use strict;

sub new
{
    my $this = shift;
    my ($config, $gladexml, $backend) = @_;
    my $class = ref($this) || $this;
    my $self = {
        gladexml => $gladexml,
        backend => $backend,
        config => $config,
    };
    bless $self, $class;

    $backend->add_observer($self);
    $self->clear();
  
    return $self;
}

sub update_track
{
    my ($self, $album, $track) = @_;
    my $gladexml = $self->{'gladexml'};
    my $backend = $self->{'backend'};

    my $container = $gladexml->get_widget('peventbox');
    my $artist_lbl = $gladexml->get_widget('partist');
    my $album_lbl = $gladexml->get_widget('palbum');
    my $track_lbl = $gladexml->get_widget('ptrack');

    $container->set_app_paintable(1);
    $artist_lbl->set_text($track->{'artist'});
    $album_lbl->set_text($album->{'album'});
    $track_lbl->set_text($track->{'title'});

    my ($window_w, $window_h) = 
        $gladexml->get_widget('main_window')->get_size();

    my $button = $gladexml->get_widget('palbumart');
    my $button_size = $button->allocation;
    foreach my $child ($button->get_children)
    {
        $button->remove($child);
    }

    my $file = $backend->{'music_base'} . "/" .  $album->{'image_path'};

    my $image;
    if (!defined($album->{'image_path'}) || !(-e $file))
    {
        $file = $self->{'config'}->{'broken_image_file'};
    }

    eval
    {
        $image = Shrill::Utility::scale_image_to_allocation($file, 
            $button_size);
    };
    if ($@) 
    {
        # GDK can barf on paths with high ascii characters here
        $file = $self->{'config'}->{'broken_image_file'};
        $image = Shrill::Utility::scale_image_to_allocation($file, 
            $button_size);
    }

    $button->add($image);
    $button->can_focus(0);
    $button->show_all;

    # set up a timer to display time left
    if ($self->{'timeout'} > 0)
    {
        Glib::Source->remove($self->{'timeout'});
    }
    $self->update_clock();
    $self->{'timeout'} = Glib::Timeout->add(1000, 
        sub { $self->update_clock(); });
}

sub update_clock
{
    my ($self) = @_;
    $self->{'time'}++;
    
    if ($self->{'time'} > $self->{'max_time'})
    {
        $self->{'time'} = $self->{'max_time'};
    }

    my $label = $self->{'gladexml'}->get_widget('playback_clock');

    my $min = $self->{'time'} / 60;
    my $sec = $self->{'time'} % 60;

    my $total_min = $self->{'max_time'} / 60;
    my $total_sec = $self->{'max_time'} % 60;

    my $timestr = sprintf "%02d:%02d / %02d:%02d", $min, $sec,
        $total_min, $total_sec;

    $label->set_text($timestr);
    1;
}

sub update_queue
{
    my ($self, @tracks) = @_;

    my $label = $self->{'gladexml'}->get_widget('pnext');

    my $next = shift @tracks;

    my $next_str = '';
    if (defined($next))
    {
        $next_str = 'Next: ' . $next->{'artist'} . ' - ' . $next->{'title'};
    }
    $label->set_text($next_str);
}

sub notify_track_changed
{
    my ($self,$album,$track,$time) = @_;
    $self->{'time'} = $time;
    $self->{'max_time'} = $track->{'duration'};
    $self->update_track($album, $track);
}

sub notify_queue_changed
{
    my $self = shift;
    my $backend = $self->{'backend'};
    my @next = $backend->get_current_queue();
    $self->update_queue(@next);
}

sub notify_track_stopped
{
    my $self = shift;
    if ($self->{'timeout'} > 0)
    {
        Glib::Source->remove($self->{'timeout'});
    }
}

sub clear
{
    my ($self) = @_;
    my $gladexml = $self->{'gladexml'};
    my $artist_lbl = $gladexml->get_widget('partist');
    my $album_lbl = $gladexml->get_widget('palbum');
    my $track_lbl = $gladexml->get_widget('ptrack');
    my $button = $gladexml->get_widget('palbumart');
    my $next = $self->{'gladexml'}->get_widget('pnext');
    my $clock = $self->{'gladexml'}->get_widget('playback_clock');

    $artist_lbl->set_text('');
    $album_lbl->set_text('');
    $track_lbl->set_text('');
    $next->set_text('');
    $clock->set_text('');

    foreach my $child ($button->get_children)
    {
        $button->remove($child);
    }
}

1;

__END__
=head1 NAME

NowPlaying - Shrill module for displaying now playing screen

=head1 SYNOPSIS

use NowPlaying;

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
