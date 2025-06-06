{
  zramSwap = {
    enable = true;
    memoryPercent = 100;
  };

  # https://github.com/NixOS/nixpkgs/pull/268121
  # https://wiki.archlinux.org/title/Zram#Optimizing_swap_on_zram
  boot.kernel.sysctl = {
    "vm.page-cluster" = 0;
    "vm.swappiness" = 180;
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;
  };
}
