{
  description = "A flake for the Lightworks video editor";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; config.allowUnfree = true;};
      fullPath = pkgs.lib.makeLibraryPath [
        pkgs.stdenv.cc.cc
        pkgs.gtk3
        pkgs.gdk-pixbuf
        pkgs.cairo
        pkgs.libjpeg_original
        pkgs.glib
        pkgs.pango
        pkgs.libGL
        pkgs.libGLU
        pkgs.nvidia_cg_toolkit
        pkgs.zlib
        pkgs.openssl
        pkgs.libuuid
        pkgs.alsa-lib
        pkgs.libjack2
        pkgs.udev
        pkgs.freetype
        pkgs.libva
        pkgs.libvdpau
        pkgs.twolame
        pkgs.gmp
        pkgs.libdrm
        pkgs.libpulseaudio
      ];
    in
    {
      packages.${system}.default = pkgs.buildFHSEnv {
        name = "lightworks-fhs";
        targetPkgs = pkgs: [
          (pkgs.stdenv.mkDerivation rec {
            pname = "lightworks";
            version = "2025.1";
            rev = "148287";

            src = pkgs.fetchurl {
              url = "https://cdn.lwks.com/releases/${version}/lightworks_${version}_r${rev}.deb";
              sha256 = "sha256-opYbWzZYim5wqSaxDeGmc10XxFkkE521PDB8OULh7Jc=";
            };

            nativeBuildInputs = [ pkgs.makeWrapper ];
            buildInputs = [ pkgs.dpkg ];

            unpackPhase = "dpkg-deb -x ${src} ./";

            installPhase = ''
              mkdir -p $out/bin
              substitute usr/bin/lightworks $out/bin/lightworks \
                --replace "/usr/lib/lightworks" "$out/lib/lightworks"
              chmod +x $out/bin/lightworks

              cp -r usr/lib $out
              cp -r usr/share $out/share

              # Ensure strings.txt is in the expected location
              if [ -f usr/share/lightworks/strings.txt ]; then
                cp usr/share/lightworks/strings.txt $out/share/lightworks/
              fi

              echo "<?xml version='1.0'?>
              <!DOCTYPE fontconfig SYSTEM 'urn:fontconfig:fonts.dtd'>
              <fontconfig>
                  <dir>/usr/share/fonts/truetype</dir>
                  <include>/etc/fonts/fonts.conf</include>
              </fontconfig>" > $out/lib/lightworks/fonts.conf

              patchelf \
                --interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
                $out/lib/lightworks/ntcardvt

              wrapProgram $out/lib/lightworks/ntcardvt \
                --prefix LD_LIBRARY_PATH : $out/lib/lightworks:${fullPath} \
                --set FONTCONFIG_FILE $out/lib/lightworks/fonts.conf \
                --set STRINGS_FILE_PATH $out/share/lightworks/strings.txt
            '';

            dontPatchELF = true;

            meta = {
              description = "Professional Non-Linear Video Editor";
              homepage = "https://www.lwks.com/";
              license = pkgs.lib.licenses.unfree;
              maintainers = with pkgs.lib.maintainers; [
                antonxy
                vojta001
                kashw2
              ];
              platforms = [ "x86_64-linux" ];
            };
          })
        ];
        runScript = "lightworks";
      };

      apps.${system}.lightworks = {
        type = "app";
        program = "${self.packages.${system}.default}/bin/lightworks";
      };
    };
}

