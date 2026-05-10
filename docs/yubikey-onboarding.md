Run the following somewhere you can plug the yubikey into:

```bash
pamu2fcfg -n -o pam://$CLUSTER_NAME.loa.internal -i pam://$CLUSTER_NAME.loa.internal
```

Copy everything between the `:` and ending `%` character. Add to `users.users.$USERNAME.yubikeys` list.