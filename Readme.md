# Typesense flake

Typesense 0.23.1 for NixOS

Below is an example of a nixos configuration using this flake :

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.funkwhale.url = "github:mmai/typesense-flake";

  outputs = { self, nixpkgs, typesense }: 
  let
    system = "x86_64-linux";
  in {
    nixosConfigurations = {

      server-hostname = nixpkgs.lib.nixosSystem {
        system = system;
        modules = [ 
          nixpkgs.nixosModules.notDetected
	        typesense.nixosModule
          ( { config, pkgs, ... }:
            { imports = [ ./hardware-configuration.nix ];

              nix = {
                package = pkgs.nixUnstable;
                extraOptions = ''
                  experimental-features = nix-command flakes
                '';
              };

              nixpkgs.overlays = [ typesense.overlay ];

              services.typesense = {
                enable = true;
              };

            })
        ];
      };

    };
  };
}
```
