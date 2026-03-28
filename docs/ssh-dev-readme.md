

log into dev linux host (debian) from host:
ssh -R 3022:localhost:3022 -R 3122:localhost:3122 -R 3222:localhost:3222 192.168.72.3  # 70.2 is the debian host

log into nixos VM (master0-test) from host:
ssh -L 3022:localhost:22 192.168.56.7  # 56.7 is nixos VM
ssh -L 3022:localhost:22 -i ~/.ssh/deployment colmena@192.168.56.7 

then on dev linux VM
ssh -i ~/.ssh/deployment colmena@localhost -p 3022



```bash
# do all at once
ssh -fN -L 3022:localhost:22 192.168.56.15 & \
ssh -fN -L 3122:localhost:22 192.168.56.13 & \
ssh -fN -L 3222:localhost:22 192.168.56.14
```