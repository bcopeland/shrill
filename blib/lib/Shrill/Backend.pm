#
#  Talks to mserv to play files.  This could be a whole lot easier if 
#  mserv exposed the mapping of directory name to album ID.  But they
#  are sorted in alphabetical order by albumname so we can hopefully
#  follow suit and build the map ourselves.  
#
package Shrill::Backend;

use Gtk2::Helper;
use IO::Socket::INET;
use IO::Handle;
use Carp;

use strict;

our $music_dir;  
our $debug = 1;

sub new
{
    my $this = shift;
    my $config = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    $self->initialize($config);
    return $self;
}

sub add_observer
{
    my $self = shift;
    push @{ $self->{'observers'} }, $_[0];
}

sub initialize
{
    my ($self, $config) = @_;

    $debug = $config->{'debug'};

    $music_dir = $config->{'music_dir'};
    $self->{'music_base'} = $music_dir;

    my @albums = build_album_list($config->{'mserv_meta_dir'});

    $self->{'albums'} = \@albums;

    my $sock = IO::Socket::INET->new (PeerAddr => $config->{'mserv_server'}, 
        PeerPort => $config->{'mserv_port'}, Proto => 'tcp') || 
        croak $@;

    $sock->autoflush(1);
    $self->{'sock'} = $sock;

    # open up two pipes - one for status info and one for command data.
    # then start a process to continually read from the socket and post
    # to the pipes.
    my ($statin, $statout, $msgin, $msgout);
    pipe($statin, $statout);
    pipe($msgin, $msgout);

    my $pid = fork();
    if ($pid == 0)
    {
        close($msgin);
        close($statin);
        $statout->autoflush(1);
        $msgout->autoflush(1);
        process_messages($self->{'sock'}, $statout, $msgout);
        exit(0);
    }

    close($msgout);
    close($statout);
    $self->{'statin'} = $statin;
    $self->{'msgin'} = $msgin;

    my $tag = Gtk2::Helper->add_watch(fileno($statin), 'in', 
        sub { $self->update_status });

    $self->get_response();
    $self->send_message("USER " . $config->{'mserv_user'});
    my @response = $self->send_message("PASS " . $config->{'mserv_pass'} . 
        " RTCOMPUTER");
    if ($response[0] !~ /^2/)
    {
        croak "error recieved from server: $response[0]";
    }
}

sub DESTROY
{
    my $self = shift;
    close $self->{'sock'};
}

#
# Redirect any messages on the socket to different pipes based 
# on type.  
#
sub process_messages
{
    my ($sock, $statout, $msgout) = @_;
    while (my $l = <$sock>)
    {
        if ($l !~ /^=/)
        {
            print $msgout $l;
        }
        else
        {
            if ($l =~ /=6(19)|(22)|(23)/)
            {
                print $statout $l;
            }
            else
            {
                if ($debug) { print "- $l"; }
            }
        }
    }
}

sub send_message
{
    my ($self, $out) = @_;
    my $sock = $self->{'sock'};
    print $sock $out, "\r\n";

    if ($debug) { print "> $out\n"; }

    my @response = $self->get_response();
    return @response;
}

sub get_response
{
    my ($self) = @_;
    my @response, my $l;
    
    my $file = $self->{'msgin'};
    while (defined($l = <$file>) && $l !~ /^\./)
    {
        $l =~ s/\r\n$//;
        if ($debug) { print "< $l\n"; }
        push @response, $l;
    }
    return @response;
}

# We recognize the following status codes and send the rest to the
# bit bucket:
#
# 619: queue update
# 622: a file started playing
# 623: a file stopped playing
#
# This method isn't bulletproof - it's possible that multiple lines
# could get here before they are read out, and we can't just select()
# because the filehandles are buffered.  This problem is mitigated
# somewhat by only sending the lines we care about down the pipe.  
#
sub update_status
{
    my ($self) = shift;
    my $fh = $self->{'statin'};
    my $l1 = <$fh>;

    $l1 =~ s/\r\n$//;

    if ($debug) { print "+ $l1\n"; }

    if ($l1 =~ /^=619/) 
    {
        foreach my $o (@{$self->{'observers'}})
        {
            $o->notify_queue_changed();
        }
    } 
    elsif ($l1 =~ /^=622/) 
    {
        my ($code, $who, $album_id, $track_id, $artist, $title, $heard,
            $duration) = split(/\t/, $l1);
        foreach my $o (@{$self->{'observers'}})
        {
            my $track = 
            {
                number => $track_id,
                artist => $artist,
                title => $title,
                duration => string_to_time($duration),
            };
            $o->notify_track_changed($self->{'albums'}[$album_id-1], $track);
            $o->notify_queue_changed();
        }
    }
    elsif ($l1 =~ /^=623/) 
    {
        foreach my $o (@{$self->{'observers'}})
        {
            $o->notify_track_stopped();
        }
    } 
    1;
}

sub queue_file
{
    my ($self, $album_id, $track_id) = @_;
    $self->send_message("QUEUE $album_id $track_id");
}

#
# Initiates playback.
#
sub play
{
    my ($self) = @_;
    $self->send_message("PLAY");
}

#
# Stops playback.
# 
sub stop
{
    my ($self) = @_;
    $self->send_message("STOP");
}

#
# Skips to next track 
# 
sub next_track
{
    my ($self) = @_;
    $self->send_message("NEXT");
}

#
#  Returns ($album, $track, $time) for what is now playing.
#
sub get_current_track
{
    my ($self) = @_;
    my @result = $self->send_message("STATUS");
    shift @result;  # response header
    my ($a, $b, $c, $album_id, $track_id, $artist, $title, $d, $time) = 
        split(/\t/, shift @result);

    if ($album_id == 0) { return undef; }

    # we have to send an info to get the full song duration.  
    my @result = $self->send_message("INFO");
    shift @result;
    my @fields = split(/\t/, shift @result);
    my $duration = $fields[14];

    my $track = 
    {
        number => $track_id,
        artist => $artist,
        title => $title,
        duration => string_to_time($duration),
    };

    # convert time to seconds
    my $time = string_to_time($time);

    return ($self->{'albums'}[$album_id-1], $track, $time);
}

sub get_current_queue
{
    my ($self) = @_;
    my @result = $self->send_message("QUEUE");
    shift @result;  # response header

    my @tracks = ();
    foreach my $line (@result)
    {
        my ($user, $album_id, $track_id, $artist, $title, $heard, $duration)
            = split(/\t/, $line);
        my $track = {
            number => $track_id,
            artist => $artist,
            title => $title,
            duration => string_to_time($duration),
        };
        push @tracks, $track;
    }
    return @tracks;
}

sub get_tracks
{
    my ($self, $album_id) = @_;
    my @tracks;

    my @result = $self->send_message("TRACKS $album_id");
    shift @result;  # response header
    shift @result;  # album name

    foreach my $line (@result)
    {
        my ($album, $number, $artist, $title, $last_play, $duration) = 
            split(/\t/, $line);

        my $track = 
        {
            number => $number,
            artist => $artist,
            title => $title,
            duration => $duration,
        };
        push @tracks, $track
    }
    return @tracks;
}

sub build_album_list
{
    my ($mserv_meta_dir) = @_;
    my @album_list;

    traverse(\@album_list, $mserv_meta_dir, ".");

    @album_list = sort 
    { 
        if ($a->{'artist'} eq $b->{'artist'})
        {
            return $a->{'album'} cmp $b->{'album'};
        }
        return $a->{'artist'} cmp $b->{'artist'};
    } @album_list;

    my $count = 0;
    foreach my $album (@album_list)
    {
        $album->{'id'} = ++$count;
    }

    return @album_list;
}

sub traverse
{
    my ($listref, $base, $reldir) = @_;
 
    my $dir;
    opendir($dir, "$base/$reldir") || croak "could not open $base/$reldir";
    my @files = grep {!/^\.\.?$/} readdir($dir);
    closedir($dir);

    my $has_album = 0;
    my $has_track = 0;
    foreach my $f (@files)
    {
        next if (-l "$base/$reldir/$f");

        if (-d "$base/$reldir/$f") 
        {
            traverse($listref, $base, "$reldir/$f");
        }
        $has_track |= ($f =~ /.trk$/);
        $has_album |= ($f eq "album");
    }

    $reldir =~ s/^.\///;

    # don't put in old trash - make sure the corresponding music dir exists
    if (! -e "$music_dir/$reldir")
    {
        return;
    }

    if ($has_track || $has_album)
    {
        my ($author, $title) = read_album("$base/$reldir/album");
        if (!defined($author))
        {
            $author = "!-Unindexed";
            $title = $reldir;
        }

        # look for album art 
        my $imgdir;
        opendir ($imgdir, "$music_dir/$reldir");
        my @images = grep { /\.(jpg|png|jpeg|gif)$/ } readdir($imgdir);
        closedir ($imgdir);

        my $image_path = undef;
        my $largest = 0;
        foreach my $image (@images)
        {
            # pick the largest in case there is crap like 1x1 gifs sitting
            # around (I have lots of these).
            my $file = "$reldir/$image";
            my $fsiz = (stat("$music_dir/$file"))[7];
            if ($fsiz > $largest)
            {
                $image_path = $file;
                $largest = $fsiz;
            }
        }

        my $album = { 
            artist => $author,
            album =>  $title,
            image_path => $image_path,
        };
        push @{ $listref }, $album;
    }
}

sub read_album
{
    my ($file) = @_;
    my ($fh, $author, $title);
    open ($fh, "<$file");
    while (<$fh>)
    {
        if (/_author=(.*)/) { $author = $1; }
        elsif (/_name=(.*)/) { $title = $1; }
    }
    close ($fh);
    return ($author, $title);
}

sub string_to_time
{
    my ($time) = shift;
    my ($min, $sec) = (split(/:/, $time));
    return $min * 60 + $sec;
}

1;
__END__
=head1 NAME

Backend - Shrill module for talking to mserv backend

=head1 SYNOPSIS

use Backend;

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
