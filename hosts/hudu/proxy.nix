{
  flake,
  config,
  pkgs,
  lib,
  ...
}:
let
  numOfAllowedProxies = builtins.readDir "${flake}/users" |> builtins.attrValues |> builtins.length;
in
{
  sops.secrets =
    (builtins.genList (
      i:
      lib.nameValuePair "PROXY_IPS/${toString i}" {
        owner = config.users.users.caddy.name;
        inherit (config.users.users.caddy) group;
      }
    ) numOfAllowedProxies)
    |> builtins.listToAttrs;

  services.caddy = {
    enable = true;
    package = pkgs.caddy;
    email = "admin@amt.com.au";

    globalConfig = ''
      servers {
        timeouts {
          read_body 10s
        }
      }
    '';

    extraConfig = ''
      (caching) {
        header {
          Cache-Control "public, max-age=604800, must-revalidate"
        }
      }

      (compression) {
        encode {
          zstd
          gzip
          match {
            header Content-Type image/*
            header Content-Type text/*
            header Content-Type video/*
            header Content-Type application/javascript*
            header Content-Type application/json*
            header Content-Type application/xml*
            header Content-Type application/font*
            header Content-Type application/otf*
            header Content-Type application/ttf*
          }
        }
      }

      (init_vars) {
        ${
          builtins.genList (
            i: "vars PROXY_IP_${toString i} `{file.${config.sops.secrets."PROXY_IPS/${toString i}".path}}`"
          ) numOfAllowedProxies
          |> builtins.concatStringsSep "\n"
        }
      }
      (trusted_request) {
        expression <<CEL
        client_ip('10.100.0.1/24', ${
          builtins.genList (i: "{vars.PROXY_IP_${toString i}}") numOfAllowedProxies
          |> builtins.concatStringsSep ","
        })
        CEL
      }

      (onlinewebsite) {
        import security
        import caching
        import compression

        header {
          X-Robots-Tag "noarchive, notranslate"
        }
      }

      (security) {
        header {
          X-Robots-Tag "noindex, nofollow, noarchive, nosnippet, notranslate, noimageindex"
        }

        # Unusual URL rewrite
        try_files {path} {path}/ /index.*

        @failed_security <<CEL
          path_regexp('\\.(php|pl|py|cgi|sh|bat|yml)$')
          || path_regexp('/\\.github|cache|bin|logs|test.*|content|core|php|config|lib|rel|priv|tracker/.*$')
          || path_regexp('/(core|content|test|system|vendor)/.*\\.(txt|xml|md|html|yaml|php|pl|py|cgi|twig|sh|bat|yml|js)$')
          || path_regexp('(/|^)\\.[A-z0-9-/\\.+_]+$')
          || path_regexp('\\.(log|rg)$')
          || path_regexp('/(index.php.*|wp-admin.php|wp-login.php|wp-config.php.*|xmlrpc.php|config.production.json|config.development.json|index.js|package.json|renovate.json|.*lock|mix.*|ghost.js|startup.js|\\.editorconfig|\\.eslintignore|\\.eslintrc.json|\\.gitattributes|\\.gitignore|\\.gitmodules|\\.npmignore|Gruntfile.js|LICENSE|MigratorConfig.js|LICENSE.txt|composer.lock|composer.json|nginx.conf|web.config|htaccess.txt|\\.htaccess)')
          || header_regexp('User-Agent', '(aesop_com_spiderman|alexibot|backweb|batchftp|bigfoot|blackwidow|blowfish|botalot|buddy|builtbottough|bullseye|cheesebot|chinaclaw|cosmos|crescent|custo|da|diibot|disco|dittospyder|dragonfly|drip|easydl|ebingbong|erocrawler|exabot|eyenetie|filehound|flashget|flunky|frontpage|getright|getweb|go-aheah-got-it|gotit|grabnet|grafula|harvest|hloader|hmview|httplib|humanlinks|ilsebot|infonavirobot|infotekies|intelliseek|interget|iria|jennybot|jetcar|joc|justview|jyxobot|kenjin|keyword|larbin|leechftp|lexibot|lftp|libweb|likse|linkscan|linkwalker|lnspiderguy|lwp|magnet|mag-net|markwatch|memo|miixpc|mirror|missigua|moget|nameprotect|navroad|backdoorbot|nearsite|netants|netcraft|netmechanic|netspider|nextgensearchbot|attach|nicerspro|nimblecrawler|npbot|openfind|outfoxbot|pagegrabber|papa|pavuk|pcbrowser|pockey|propowerbot|prowebwalker|psbot|pump|queryn|recorder|realdownload|reaper|reget|true_robot|repomonkey|rma|internetseer|sitesnagger|siphon|slysearch|smartdownload|snake|snapbot|snoopy|sogou|spacebison|spankbot|spanner|sqworm|superbot|superhttp|surfbot|asterias|suzuran|szukacz|takeout|teleport|telesoft|thenomad|tighttwatbot|titan|urldispatcher|turingos|turnitinbot|vacuum|vci|voideye|libwww-perl|widow|wisenutbot|wwwoffle|xaldon|xenu|zeus|zyborg|anonymouse|zip|mail|enhanc|fetch|auto|bandit|clip|copier|master|reaper|sauger|quester|whack|picker|catch|vampire|hari|offline|track|craftbot|download|extract|stripper|sucker|ninja|clshttp|webspider|leacher|collector|grabber|webpictures|seo|hole|copyright|check)')
          CEL

        handle @failed_security {
          respond 403 {
            body "Access denied: Security check failed"
          }
        }
      }

      (proxy) {
      	header_up X-Real-IP {remote}
      }

      (error-handler) {
      	handle {
      		error 404
      	}

      	handle_errors {
      		@body_error header Accept *text/html*
      		abort
      	}
      }

      (shared_access_tag) {
        header_up X-Forwarded-Shared-Access true
      }

      (shared-check) {
        query X-Forwarded-Shared-Access=true
      }

      (cors) {
        @cors_preflight{args[0]} method OPTIONS
        @cors{args[0]} header Origin {args[0]}

        handle @cors_preflight{args[0]} {
          header {
            Access-Control-Allow-Origin "{args[0]}"
            Access-Control-Allow-Methods "GET, POST, PUT, PATCH, DELETE, OPTIONS"
            Access-Control-Allow-Headers *
            Access-Control-Max-Age "3600"
            defer
          }
          respond "" 204
        }

        handle @cors{args[0]} {
          header {
            Access-Control-Allow-Origin "{args[0]}"
            Access-Control-Expose-Headers *
            defer
          }
        }
      }
    '';

    virtualHosts."cipp.amt.com.au".extraConfig = ''
      import compression

      import init_vars
      @trusted_request {
        import trusted_request
      }

      handle @trusted_request {
        reverse_proxy https://jolly-mushroom-0bc4a9810.5.azurestaticapps.net
      }
    '';
  };

  networking.firewall = {
    allowedTCPPorts = [
      80
      443
    ];
    allowedUDPPorts = [ 443 ];
  };
}
