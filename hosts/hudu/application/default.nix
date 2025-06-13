{
  config,
  pkgs,
  lib,
  ...
}:
let
  huduDomain = config.virtualisation.oci-containers.containers.hudu-app.environment.DOMAIN;
in
{
  sops.secrets = {
    HUDU_ENV = {
      restartUnits = [
        "podman-hudu-app.service"
        "podman-hudu-worker.service"
      ];
    };
  };

  virtualisation.oci-containers = {
    backend = "podman";
    containers =
      let
        huduImage = pkgs.dockerTools.buildLayeredImage {
          name = "modified-hudu";
          tag = "latest";

          # Get required parameters for updating by running:
          # nix run nixpkgs#nix-prefetch-docker -- --image-name "hududocker/hudu"
          fromImage = pkgs.dockerTools.pullImage (import ./docker-image.nix);

          # Patches the export jobs to complete the following:
          # Send the exported csv file into a subdirectory of the S3 bucket called "exports"
          # Create the S3 client with force_path_style set to true
          extraCommands =
            let
              huduRuntimePath = "/var/www/hudu2";
            in
            ''
              #!${pkgs.runtimeShell}
              ${lib.getExe pkgs.perl} -0777 -pi -e 's/(Aws::S3::Client\.new\()((?:\n\s+(?:(?!force_path_style:)[a-z_]+):\s[0-9a-z\._]+,)+)(?!force_path_style: true)(\n\s+\))/\1\2\n        force_path_style: true,\3/g' ${huduRuntimePath}/app/jobs/exports_job.rb
              ${lib.getExe pkgs.perl} -pi -e 's/key: zipname/key: "exports\/\#{zipname}"/' ${huduRuntimePath}/app/jobs/exports_job.rb
            '';

          config = {
            Cmd = [ "/usr/local/bin/docker-entrypoint.sh" ];
            WorkingDir = "/var/www/hudu2";
          };
        };

        huduEnv = {
          PGUID = "1000";
          PGID = "1000";
          ONLY_SUBDOMAINS = "true";
          VALIDATION = "http";
          STAGING = "false";
          DISABLE_SSL = "true";

          DOMAIN = "hudu.amt.com.au";
          URL = "amt.com.au";
          SUBDOMAINS = "hudu";

          RAILS_ENV = "production";
          RACK_ENV = "production";
          RAILS_MAX_THREADS = "50";

          REDIS_URL = "redis://host.containers.internal:6379";
          DB_HOST = "host.containers.internal";
          DB_USERNAME = "hudu";
          DB_NAME = "hudu_production";
          POSTGRES_HOST_AUTH_METHOD = "md5";

          SMTP_PORT = "2525";
          SMTP_STARTTLS_AUTO = "true";
          SMTP_AUTHENTICATION = "login";
          SMTP_OPENSSL_VERIFY_MODE = "none";

          USE_LOCAL_FILESYSTEM = "false";
          S3_FORCE_PATH_STYLE = "true";
          S3_ENDPOINT = "https://s3.amt.com.au/";
        };
      in
      rec {
        hudu-app = {
          image = "modified-hudu:latest";
          imageFile = huduImage;
          ports = [ "3000:3000" ];
          environment = huduEnv;
          environmentFiles = [ config.sops.secrets.HUDU_ENV.path ];
          networks = [ "podman" ];
          volumes = [ "hudu_app_data:/var/lib/app/data" ];
        };

        hudu-worker = {
          inherit (hudu-app)
            image
            imageFile
            environment
            environmentFiles
            networks
            ;
          cmd = [
            "bundle"
            "exec"
            "sidekiq"
            "-C"
            "config/sidekiq.yml"
          ];
        };
      };
  };

  systemd.services = {
    podman-hudu-app = {
      after = [
        "postgresql.service"
        "podman-volume-hudu_app_data.service"
      ];
      requires = [
        "postgresql.service"
        "podman-volume-hudu_app_data.service"
      ];
    };

    podman-volume-hudu_app_data = {
      path = [ pkgs.podman ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        podman volume inspect hudu_app_data || podman volume create hudu_app_data
      '';
    };
  };

  networking.firewall.interfaces.podman0.allowedTCPPorts = [ 3000 ];

  services.caddy.virtualHosts."${huduDomain}" = {
    extraConfig = ''
      import caching
      import compression

      import init_vars
      @trusted_request {
        import trusted_request
      }

      handle @trusted_request {
        reverse_proxy {
          to http://localhost:3000
          import proxy
        }
      }

      #<==========================>#
      #	Handle Shared URL Requests #
      #<==========================>#

      import security

      @shared_access expression <<CEL
        ({method} == "GET"
          && (path_regexp("^/shared(_article)?/([a-zA-Z0-9]+){24}")
            || (path_regexp("^/secure_notes/([0-9]+)") && matches({query.key}, "^[a-zA-Z0-9]{40}$")
        )))

        || ({method} == "POST"
          && (path_regexp("^/secure_notes/([0-9]+)/reveal")))
      CEL

      handle @shared_access {
        reverse_proxy localhost:3000 {
          import proxy
        }
      }

      @shared_asset_request {
        method GET

        # Only allow access to hudu assets that are used on the shared page.
        # The assets contain no sensitive information, and are shipped with hudu itself.
        # These assets are the javascript file which controls the password show button, the css file to control the page layout, the favicon and the font files.
        path_regexp (/cable|/app_assets/(([a-zA-Z0-9-]+)\.(css|js|ttf|woff2|png)|2x/favicon@2x-([a-z0-9]+).png))

        # Only allow requests that are coming from the shared page itself, or the css asset.
        header_regexp referer https://${huduDomain}/(${
          lib.concatStringsSep "|" [
            "shared(_article)?/([a-zA-Z0-9]{24})"
            "secure_notes/([0-9]+)"
            "app_assets/([a-zA-Z0-9-]+)\.(css)"
          ]
        })
      }

      handle @shared_asset_request {
        reverse_proxy localhost:3000 {
          import proxy
        }
      }

      #<=====================>#
      #	Handle Other Requests #
      #<=====================>#

      import error-handler
    '';
  };
}
