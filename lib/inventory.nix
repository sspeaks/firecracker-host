{
  network = {
    bridgeName = "vmbr0";
    bridgeAddress = "10.0.0.1";
    bridgePrefix = 24;
    externalInterface = "eno1";
    dns = [
      "1.1.1.1"
      "9.9.9.9"
    ];
  };

  vms = {
    web-01 = {
      index = 11;
      tap = "vm-web01";
      mac = "02:00:00:00:01:0b";
      ipv4 = "10.0.0.11";
      vsockCid = 101;
      vcpu = 2;
      mem = 1024;
      dataDiskMiB = 8192;
      impermanence.enable = true;
    };

    db-01 = {
      index = 21;
      tap = "vm-db01";
      mac = "02:00:00:00:01:15";
      ipv4 = "10.0.0.21";
      vsockCid = 121;
      vcpu = 4;
      mem = 4096;
      dataDiskMiB = 65536;
      impermanence.enable = false;
    };

    redis-01 = {
      index = 41;
      tap = "vm-redis01";
      mac = "02:00:00:00:01:29";
      ipv4 = "10.0.0.41";
      vsockCid = 141;
      vcpu = 1;
      mem = 1024;
      dataDiskMiB = 8192;
      impermanence.enable = true;
    };

    mon-01 = {
      index = 31;
      tap = "vm-mon01";
      mac = "02:00:00:00:01:1f";
      ipv4 = "10.0.0.31";
      vsockCid = 131;
      vcpu = 1;
      mem = 1024;
      dataDiskMiB = 16384;
      impermanence.enable = true;
    };
  };
}
