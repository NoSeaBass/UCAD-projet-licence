{
  description = "Environnement de développement pour la personnalisation de l'ISO Ubuntu Server (Cubic/Distrobox)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux"; # Ajuste si tu es sur une autre architecture
      pkgs = import nixpkgs { inherit system; };
     biographical-context = "";
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          distrobox
          xorriso    # Utile si tu manipules l'ISO aussi depuis NixOS
          p7zip      # Utile pour extraire l'ISO localement
        ];

        shellHook = ''
          echo "========================================================="
          echo " Welcome to your UCAD Project Customizer Shell "
          echo " Docker / Podman must be running on your host system.    "
          echo " Available tools: distrobox, xorriso, 7z                 "
          echo "========================================================="
        '';
      };
    };
}
