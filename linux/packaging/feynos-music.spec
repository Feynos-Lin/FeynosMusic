# Plain RPM for Feynos Music: no install scripts, nothing in /opt, so it installs and updates
# cleanly with dnf, GNOME Software / KDE Discover, and rpm-ostree (Silverblue, Kinoite, Bazzite).
%global debug_package %{nil}
%global __os_install_post %{nil}
%global _build_id_links none
%global __requires_exclude_from ^/usr/lib/feynos-music/.*$
%global __provides_exclude_from ^/usr/lib/feynos-music/.*$

Name:           feynos-music
Version:        %{app_version}
Release:        1
Summary:        Navidrome music player
License:        MIT
URL:            https://github.com/Feynos-Lin/FeynosMusic
BuildArch:      x86_64
AutoReqProv:    no
Requires:       nss
Requires:       alsa-lib
Requires:       gtk3
Requires:       libnotify

%description
Feynos Music for Linux: a Navidrome music player with ListenBrainz history,
weekly mixes, jams, themes and visualizers.

%install
mkdir -p %{buildroot}/usr/lib/feynos-music %{buildroot}/usr/bin \
         %{buildroot}/usr/share/applications %{buildroot}/usr/share/icons/hicolor/512x512/apps
cp -a %{app_dir}/. %{buildroot}/usr/lib/feynos-music/
ln -s ../lib/feynos-music/feynos-music %{buildroot}/usr/bin/feynos-music
install -m 0644 %{icon_file} %{buildroot}/usr/share/icons/hicolor/512x512/apps/feynos-music.png
cat > %{buildroot}/usr/share/applications/feynos-music.desktop <<DESKTOP
[Desktop Entry]
Name=Feynos Music
Comment=Navidrome music player with ListenBrainz history, weekly mixes and jams
Exec=/usr/lib/feynos-music/feynos-music %U
Terminal=false
Type=Application
Icon=feynos-music
StartupWMClass=Feynos Music
Categories=Audio;AudioVideo;Player;
DESKTOP

%files
/usr/lib/feynos-music
/usr/bin/feynos-music
/usr/share/applications/feynos-music.desktop
/usr/share/icons/hicolor/512x512/apps/feynos-music.png
