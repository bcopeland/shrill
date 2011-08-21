#! /usr/bin/perl
#
#  Properly creates the album and .trk files for ogg vorbis files.
#  Example:  ./ogg_meta /my/music /var/lib/mserv/.mservtrackinfo
#
use File::Find;
use Ogg::Vorbis::Header::PurePerl;
use strict;

(@ARGV == 2) || die "Usage $0 <music dir> <meta dir>";

my $musicdir = shift;
my $metadir = shift;

my %albums_written = ();

find(\&wanted, $musicdir);

sub wanted
{
    my $oggfile = $_;
    my $trackfile = $_ . ".trk";
    my $trackdir = $File::Find::dir;
    $trackdir =~ s/^$musicdir/$metadir/;

    if (! -e $trackdir) { mkdir $trackdir || die "error: ", $!; }

    next if ($_ !~ /\.ogg$/);

    my %info = ();

    # if there is a file already, read it to keep around other data we don't
    # care about.
    open(IN, "<$trackdir/$trackfile");
    while(<IN>)
    {
        my ($key, $val) = split(/=/);
        chomp $val;
        $info{$key} = $val;
    }
    close(IN);

    my $album = "";

    # Get the stuff from ogginfo.. 
    my $ogg = Ogg::Vorbis::Header::PurePerl->load($oggfile);    

    $info{_duration} = $ogg->info('length') * 100;
    foreach my $tag ($ogg->comment_tags)
    {
        my $value = ($ogg->comment($tag))[0];
        if ($tag =~ /ARTIST/i) { $info{_author} = $value; }
        elsif ($tag =~ /TITLE/i) { $info{_name} = $value; }
        elsif ($tag =~ /ALBUM/i) { $album = $value; }
    }

    open(OUT, ">$trackdir/$trackfile") || die "error writing: ", $!;
    foreach my $key (keys(%info))
    {
        my $value = $info{$key};
        print OUT "$key=$value\n";
    }
    close(OUT);

    print STDERR "$trackdir/$trackfile", " " x 50, "\r";

    #
    #  Write album file
    #
    if ($albums_written{$trackdir} != 1)
    {
        open (ALBUM, ">$trackdir/album");
        print ALBUM "_author=" . $info{_author} . "\n";
        print ALBUM "_name=$album\n";
        close(ALBUM);
        $albums_written{$trackdir} = 1;
    }
}
print "Done", " " x 72, "\n";
