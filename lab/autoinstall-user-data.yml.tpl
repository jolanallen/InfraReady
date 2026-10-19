#cloud-config
autoinstall:
  version: 1
  locale: en_US.UTF-8
  keyboard: {layout: fr}
  timezone: Europe/Paris
  identity:
    hostname: __HOSTNAME__
    username: infraadmin
    password: '__SHA512_PASSWORD_HASH__'
  ssh:
    install-server: true
    allow-pw: false
    authorized-keys: ['__SSH_PUBLIC_KEY__']
  network:
    version: 2
    ethernets:
      lan:
        match: {name: "en*"}
        addresses: [__IP__/24]
        routes: [{to: default, via: 192.168.50.1}]
        nameservers: {addresses: [1.1.1.1, 9.9.9.9]}
  storage:
    layout: {name: lvm, sizing-policy: all}
  packages: [qemu-guest-agent]
  updates: security
  shutdown: poweroff
