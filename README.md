# b-e-a-s-t
Bulletproof Encrypted Arch Setup (Tool) aka B.E.A.S.T


## Partition Layout
+----------------------+----------------------+----------------------+
| EFI system partition | System partition     | Swap partition       |
| unencrypted          | LUKS-encrypted       | plain-encrypted      |
|                      |                      |                      |
| /efi                 | /                    | [SWAP]               |
| /dev/sda1            | /dev/sda2            | /dev/sda3            |
|----------------------+----------------------+----------------------+      
