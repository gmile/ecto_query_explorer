{
  description = "Collect and analyze Ecto query telemetry";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      forAllSystems =
        f:
        lib.genAttrs [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ] (
          system:
          let
            pkgs = nixpkgs.legacyPackages.${system};
          in
          f {
            inherit pkgs;
            beam = pkgs.beam_minimal.packages.erlang_29;
          }
        );
      mixTools = beam: [
        beam.erlang
        beam.elixir_1_20
        beam.hex
        beam.rebar3
      ];
    in
    {
      packages = forAllSystems (
        { pkgs, beam }:
        {
          postgres = pkgs.writeShellApplication {
            name = "postgres";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.postgresql
            ];
            text = ''
              data=$(mktemp --directory)
              trap 'rm --recursive --force "$data"' EXIT
              initdb --username postgres --auth trust --encoding UTF8 --no-locale "$data" > /dev/null
              postgres -D "$data" -h 127.0.0.1 -k "" "$@"
            '';
          };
        }
      );

      checks = forAllSystems (
        { pkgs, beam }:
        let
          deps = beam.fetchMixDeps {
            pname = "ecto-query-explorer-deps";
            version = "locked";
            src = lib.fileset.toSource {
              root = ./.;
              fileset = lib.fileset.unions [
                ./mix.exs
                ./mix.lock
                ./VERSION
              ];
            };
            mixEnv = "dev";
            hash = "sha256-HbNFKr9p67EqmKOAo0PF9T8xZzGk7N2k+bHwOA31csw=";
          };
          mix =
            {
              name,
              env ? "test",
              inputs ? [ ],
              files ? [
                ./.formatter.exs
                ./mix.exs
                ./mix.lock
                ./config
                ./lib
                ./test
                ./README.md
                ./CHANGELOG.md
                ./LICENSE
              ],
              command,
            }:
            pkgs.stdenv.mkDerivation {
              inherit name;
              src = lib.fileset.toSource {
                root = ./.;
                fileset = lib.fileset.unions files;
              };
              nativeBuildInputs = mixTools beam ++ inputs;
              MIX_ENV = env;
              MIX_REBAR3 = "${beam.rebar3}/bin/rebar3";
              HEX_OFFLINE = 1;
              buildPhase = ''
                export HOME=$TMPDIR MIX_DEPS_PATH=$PWD/deps
                echo 0.0.0 > VERSION
                echo 'config :exqlite, force_build: true' >> config/config.exs
                cp --recursive --no-preserve=mode ${deps} deps
                mix deps.compile --no-deps-check
                ${command}
              '';
              installPhase = "touch $out";
            };
          plt = mix {
            name = "plt";
            env = "dev";
            files = [
              ./mix.exs
              ./mix.lock
              ./config
            ];
            command = ''
              mix dialyzer --plt
              mkdir $out
              cp priv/plts/*.plt $out
            '';
          };
        in
        {
          test = mix {
            name = "test";
            inputs = [ pkgs.postgresql ];
            command = ''
              mix format --check-formatted
              mix compile --warnings-as-errors
              mix deps.unlock --check-unused
              export PGHOST=$PWD
              ${
                lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.postgres
              } -h "" -k "$PGHOST" &> postgres.log &
              timeout 60 bash -c 'until pg_isready --quiet; do sleep 1; done' ||
                { cat postgres.log; exit 1; }
              mix test --warnings-as-errors
              kill %1
            '';
          };
          docs = mix {
            name = "docs";
            env = "dev";
            command = "mix docs --warnings-as-errors";
          };
          dialyzer = mix {
            name = "dialyzer";
            env = "dev";
            command = ''
              mkdir -p priv/plts
              cp ${plt}/* priv/plts
              mix dialyzer --no-check
            '';
          };
          nixfmt =
            pkgs.runCommand "nixfmt"
              {
                nativeBuildInputs = [ pkgs.nixfmt ];
                src = lib.fileset.toSource {
                  root = ./.;
                  fileset = lib.fileset.fileFilter (file: file.hasExt "nix") ./.;
                };
              }
              ''
                find $src -name '*.nix' -exec nixfmt --check {} +
                touch $out
              '';
        }
      );

      formatter = forAllSystems ({ pkgs, ... }: pkgs.nixfmt-tree);

      devShells = forAllSystems (
        { pkgs, beam }:
        {
          default = pkgs.mkShell {
            packages = mixTools beam ++ [
              pkgs.fish
              pkgs.gh
            ];

            shellHook = ''
              case $- in *i*) exec ${pkgs.fish}/bin/fish ;; esac
            '';
          };
        }
      );
    };
}
