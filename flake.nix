{
  description = "My personal blog";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };
  outputs =
    { nixpkgs, self }:
    let
      lib = nixpkgs.lib;
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forEachSupportedSystem =
        f: lib.genAttrs supportedSystems (system: f (import nixpkgs { inherit system; }));
    in
    {
      # `nix build .` builds the website's folder
      packages = forEachSupportedSystem (pkgs: rec {
        tobor-blog = pkgs.stdenv.mkDerivation {
          name = "tobor-blog";

          src = ./src;

          nativeBuildInputs = with pkgs; [
            pandoc
            jq
          ];

          dontUnpack = true;

          buildPhase = ''
            runHook preBuild

            SOURCEDIR="$src"
            OUTDIR="$out"

            ${builtins.readFile ./build.sh}

            runHook postBuild
          '';
        };
        default = tobor-blog;
      });

      # `nix run .` starts a local http server serving the output folder
      # `nix run .#copy` copies the built website to the current directory
      apps = forEachSupportedSystem (pkgs: rec {
        tobor-blog = {
          type = "app";
          program = toString (
            pkgs.writeShellScript "local-tobor-blog.sh" ''
              ${pkgs.lib.getExe pkgs.http-server} -c -1 -a 127.0.0.1 ${
                self.packages.${pkgs.stdenv.hostPlatform.system}.tobor-blog
              }
            ''
          );
        };
        default = tobor-blog;
        copy = {
          type = "app";
          program = toString (
            pkgs.writeShellScript "dist.sh" ''
              echo "Building blog..."
              BUILT_BLOG="$(nix build . --no-link --print-out-paths)"
              echo "Copying to current directory..."
              cp -r --no-preserve=mode,ownership,timestamps "$BUILT_BLOG"/* .
            ''
          );
        };
      });
    };
}
