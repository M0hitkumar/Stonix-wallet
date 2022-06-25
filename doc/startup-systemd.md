# Adding Stonix to startup with `systemd`

```bash
# Set config options in ~/.stonix-wallet/config
$ echo login=bob:superSecretPass123 | tee -a ~/.stonix-wallet/config

# Create service file from template
$ curl -s https://raw.githubusercontent.com/shesek/stonix-wallet/master/scripts/stonix-wallet.service |
  sed "s~{cmd}~`which stonix-wallet`~;s~{user}~`whoami`~g" |
  sudo tee /etc/systemd/system/stonix-wallet.service

# Inspect the generated service file, then load and start the service
$ sudo systemctl daemon-reload
$ sudo systemctl enable stonix-wallet && sudo systemctl start stonix-wallet
```
