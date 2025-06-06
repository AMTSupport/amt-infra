# Hopefully this won't stick around for long
{
  config,
  ...
}:
let
  huduDomain = config.virtualisation.oci-containers.containers.hudu-app.environment.DOMAIN;
in
{
  sops.secrets = {
    S3_PROXY_COMMON = {
      restartUnits = [
        "podman-s3proxy.service"
        "podman-s3proxy-backup.service"
      ];
    };
    S3_PROXY_ENV = {
      restartUnits = [ "podman-s3proxy.service" ];
    };
    S3_PROXY_BACKUP_ENV = {
      restartUnits = [ "podman-s3proxy-backup.service" ];
    };
  };

  virtualisation.oci-containers.containers =
    let
      image = "ghcr.io/gaul/s3proxy/container:latest";

      environment = {
        LOG_LEVEL = "debug";
        S3PROXY_ENDPOINT = "http://0.0.0.0:8080";
        S3PROXY_AUTHORIZATION = "aws-v4";
        JCLOUDS_PROVIDER = "azureblob";
        JCLOUDS_AZUREBLOB_AUTH = "azureKey";
        # S3PROXY_CORS_ALLOW_ORIGINS = "https://${SUBDOMAINS:?err}\\.amt\\.com\\.au";
        # S3PROXY_CORS_ALLOW_METHODS = "GET HEAD POST PUT DELETE CONNECT OPTIONS PATCH";
        # S3PROXY_CORS_ALLOW_HEADERS = "Accept Content-Type";
      };
    in
    {
      s3proxy = {
        inherit image environment;
        environmentFiles = [
          config.sops.secrets.S3_PROXY_COMMON.path
          config.sops.secrets.S3_PROXY_ENV.path
        ];
        ports = [ "8080:8080" ];
        networks = [ "podman" ];
      };

      s3proxy_backup = {
        inherit image environment;
        environmentFiles = [
          config.sops.secrets.S3_PROXY_COMMON.path
          config.sops.secrets.S3_PROXY_BACKUP_ENV.path
        ];
        ports = [ "8081:8080" ];
        networks = [ "podman" ];
      };
    };

  services.caddy.virtualHosts."s3.do.amt.com.au".extraConfig = ''
    import caching
    import compression

    #<=====================>
    #	Setup CORS Rules   #
    #<=====================>

    # import cors https://${huduDomain}

    #<=============================>
    #	Handle Internal Requests   #
    #<=============================>

    @backup_internal {
      path /backup/*
      client_ip private_ranges
    }

    handle @backup_internal {
      reverse_proxy localhost:8081
    }

    @live_internal {
      path /live-store/*
      client_ip private_ranges
    }

    handle @live_internal {
      reverse_proxy localhost:8080
    }

    @backup_trusted {
      path_regexp /backup/?.*
      client_ip private_ranges
    }

    handle @backup_trusted {
      reverse_proxy localhost:8081
    }

    #<=======================>
    #	Handle Live Bucket   #
    #<=======================>

    import security

    import init_vars
    @trusted_request {
      path /live-store/uploads/*
      header referer https://hudu.amt.com.au/
      import trusted_request
    }

    handle @trusted_request {
      reverse_proxy localhost:8080 {
        import proxy
      }
    }

    #<=========================>
    #	Handle Other Requests  #
    #<=========================>

    # TODO :: Assert that the time regex is actually the current date only.
    @shared_icon {
      method GET
      path_regexp ^\/live-store\/uploads\/account\/1\/shared_logo\/small-a2bc1670a8c9718a511510b6036f3d38\.jpg
      query X-Amz-Algorithm=AWS4-HMAC-SHA256
      query X-Amz-Credential=s3proxy\/[0-9]{8}\/australiaeast\/s3\/aws4_request
      query X-Amz-Date=[0-9]{8}T[0-9]{6}Z
      query X-Amz-Expires=900
      query X-Amz-SignedHeaders=host
      query X-Amz-Signature=([a-z0-9]{64})
      header referer https://${huduDomain}/
      import shared-check
    }

    handle @shared_icon {
      reverse_proxy localhost:8080 {
        import proxy
        import shared_access_tag
      }
    }
  '';

  networking.firewall.interfaces.podman0.allowedTCPPorts = [
    8080
    8081
  ];
}
