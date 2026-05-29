```bash
sudo mkdir -p /mnt/find-mc
for dir in /var/lib/longhorn/replicas/*; do
  # Find the active head image in the directory
  img=$(ls "$dir"/volume-head-*.img 2>/dev/null | head -n 1)
  
  if [ -n "$img" ]; then
    # Mount loop, read-only, AND noload to bypass the dirty journal
    sudo mount -o loop,ro,noload "$img" /mnt/find-mc 2>/dev/null
    
    # Look for standard Minecraft server files
    if [ -f "/mnt/find-mc/server.properties" ] || [ -d "/mnt/find-mc/world" ]; then
      echo -e "\n✅ FOUND MINECRAFT! The correct folder is:\n$dir\n"
      #sudo umount /mnt/find-mc
      break
    fi
    # Unmount and move to the next folder
    sudo umount /mnt/find-mc 2>/dev/null
  fi
done
```