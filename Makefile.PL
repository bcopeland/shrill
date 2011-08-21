package MY;

use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME' => 'Shrill',
    'VERSION' => '1.1',
    'PM_FILTER' => qq(perl -pe 's!__SHARE_DIR__!\\\$(PREFIX)/share!g'),
    'EXE_FILES' => [ 'main/shrill' ],
);


sub install
{
    my $par = shift->SUPER::install(@_);
    $par =~ s/doc_install/doc_install install_share install_mydoc/;
    return $par;
}

sub postamble {
    return q(
install_share: share/noart.jpg share/shrill.glade share/shrill.gtkrc
	$(MKPATH) $(PREFIX)/share/shrill
	$(CP) $^ $(PREFIX)/share/shrill

install_mydoc: README sample.config
	$(MKPATH) $(PREFIX)/share/doc/shrill
	$(CP) $^ $(PREFIX)/share/doc/shrill
);
}
