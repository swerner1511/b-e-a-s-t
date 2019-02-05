# b-e-a-s-t
Bulletproof Encrypted Arch Setup (Tool) aka B.E.A.S.T


## Partition Layout
```
+----------------------+----------------------+----------------------+
| EFI system partition | System partition     | Swap partition       |
| unencrypted          | LUKS-encrypted       | plain-encrypted      |
|                      |                      |                      |
| /efi                 | /                    | [SWAP]               |
| /dev/sda1            | /dev/sda2            | /dev/sda3            |
+----------------------+----------------------+----------------------+
```

## How to use
nano b-e-a-s-t.sh \
change values \
chmod +x b-e-a-s-t.sh \
sh ./b-e-a-s-t.sh \
follow instructions

```
...

# DEFAULT Values for Script Variables (Change to your needs)
DRIVE=/dev/sda
HOSTNAME=your-hostname
_USERNAME=your-username
_USERPWD=your-userpwd
_ROOTPWD=root-pwd
TIMEZONE=Europe/Berlin
LOCALE=de_DE
KEYMAP=de-latin1-nodeadkeys

...
```
