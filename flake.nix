{
  description = "Typesense";

  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      version = "0.24.1";
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; overlays = [ self.overlay ]; });

    in

    {
      overlay = final: prev: {

        typesense = with final; stdenv.mkDerivation rec {
          pname = "typesense";
          inherit version;

          src = fetchurl {
            url = "https://dl.typesense.org/releases/${version}/typesense-server-${version}-linux-amd64.tar.gz";
            sha256 = "sha256-bmvje439QYivV96fjnEXblYJnSk8C916OwVeK2n/QR8=";
          };

          nativeBuildInputs = [
            pkgs.autoPatchelfHook
          ];

          sourceRoot = ".";

          installPhase = ''
            mkdir -p $out/bin
            cp $sourceRoot/typesense-server $out/bin
          '';
        };
      };


      packages = forAllSystems (system:
        {
          inherit (nixpkgsFor.${system}) typesense;
        });

      defaultPackage = forAllSystems (system: self.packages.${system}.typesense);

      nixosModules.typesense =
        { config, lib, pkgs, ... }:
        let
          cfg = config.services.typesense;
        in
        {

          options = {
            services.typesense = {
              enable = lib.mkEnableOption "typesense";

              user = lib.mkOption {
                type = lib.types.str;
                default = "typesense";
                description = "User under which Typesense is ran.";
              };

              group = lib.mkOption {
                type = lib.types.str;
                default = "typesense";
                description = "Group under which Typesense is ran.";
              };

              dataDir = lib.mkOption {
                type = lib.types.str;
                default = "/var/lib/typesense";
                description = ''
                  Where to keep the typesense data.
                  '';
              };

              logDir = lib.mkOption {
                type = lib.types.str;
                default = "/var/log/typesense";
                description = ''
                  Path to the log directory.
                  '';
              };

              apiAddress = lib.mkOption {
                type = lib.types.str;
                default = "0.0.0.0";
                description = ''
                  Address to which Typesense API service binds.
                  '';
              };

              apiPort = lib.mkOption {
                type = lib.types.port;
                default = 8108;
                description = ''
                  Port on which Typesense API service listens.
                  '';
              };

              apiKey = lib.mkOption {
                type = lib.types.str;
                description = ''
                  API key that allows all operations.
                  '';
                example = "my-secret-api-key";
              };
            };
          };

          config = lib.mkIf cfg.enable {
            users.users.typesense = lib.mkIf (cfg.user == "typesense") {
              group = cfg.group; 
              isSystemUser = true;
            };
            users.groups.typesense = lib.mkIf (cfg.group == "typesense") {};

            systemd.tmpfiles.rules = [
              "d ${cfg.dataDir} 0755 ${cfg.user} ${cfg.group} - -"
              "d ${cfg.logDir} 0755 ${cfg.user} ${cfg.group} - -"
            ];

            systemd.targets.typesense = {
              description = "Typesense";
              wants = ["typesense-server.service"];
            }; 
            systemd.services = {
              typesense-server = {
                description = "Typesense Server";
                wants = [ "network.target" "remote-fs.target" ];
                after = [ "network.target" "remote-fs.target" ];
                wantedBy = [ "multi-user.target" ];
                serviceConfig = {
                  User = "${cfg.user}";
                  Group = "${cfg.group}";
                  ExecStart = ''${pkgs.typesense}/bin/typesense-server \
                    --data-dir ${cfg.dataDir} \
                    --log-dir ${cfg.logDir} \
                    --api-key ${cfg.apiKey} \
                    --api-address ${cfg.apiAddress} \
                    --api-port ${cfg.apiPort} \
                    '';
                  Restart = "on-failure";
                  LimitNOFILE = 64000;
                  LimitMEMLOCK = "infinity";
                };

              };

            };
          };
        };

      nixpkgs.overlays = [ self.overlay ];
      environment.systemPackages = [ nixpkgs.typesense ];
    };
}
