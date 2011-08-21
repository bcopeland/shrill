package Shrill::Utility;
# 
#  Misc subs used in various places.
#

use strict;

sub min
{
    return ($_[0] < $_[1]) ? $_[0] : $_[1];
}

#
#  Loads an image from disk and sizes it to match 95% of the allocation.
#
sub scale_image_to_allocation
{
    my ($file, $allocation) = @_;
    my $pixbuf = Gtk2::Gdk::Pixbuf->new_from_file($file);
    my $aspect = $pixbuf->get_height / $pixbuf->get_width;
    my $target_w = .95 * min($allocation->width, $allocation->height);
    my $target_h = $aspect * $target_w;

    if ($target_w < 1 || $target_h < 1) { return; }

    my $scaled = $pixbuf->scale_simple($target_w, $target_h, 'bilinear');
    my $image = Gtk2::Image->new_from_pixbuf($scaled);
    return $image;
}

#
#  Escapes text to be used as markup.  As far as I can tell the glib function
#  that does this already doesn't exist in the perl bindings.
#
sub escape_xml
{
    my ($str) = @_;

    $str =~ s/\&/\&amp;/g;
    $str =~ s/</&lt;/g;
    $str =~ s/>/&gt;/g;
    $str =~ s/"/&quot;/g;
    return $str;
}

1;
__END__
=head1 NAME

Utility - Shrill module for misc functions

=head1 SYNOPSIS

use Utility;

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
