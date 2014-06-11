ctmg
====

Encrypted container manager, wrapper around cryptsetup on loopback files

### Usage

```bash
ctmg [ new | delete | open | close ] container_path [cmd_arguments]
    ctmg new	container_path container_size (in MB)
    ctmg delete	container_path
    ctmg open	container_path
    ctmg close	container_path
```

### Examples

#### Creating a 100MB encrypted container called "example"

Will create "example.ct" in the current directory, and mount in in "example/".

```bash
$ ctmg new example 100

[-] dd if=/dev/zero of=./example.ct bs=1M count=100
100+0 records in
100+0 records out
104857600 bytes (105 MB) copied, 0.105838 s, 991 MB/s
[-] sudo cryptsetup --cipher aes-xts-plain64 --key-size 512 --hash sha512 --iter-time 5000 --use-random --verify-passphrase luksFormat ./example.ct

WARNING!
========
This will overwrite data on ./example.ct irrevocably.

Are you sure? (Type uppercase yes): YES
Enter passphrase: 
Verify passphrase: 
[-] sudo cryptsetup luksOpen ./example.ct ct_example
Enter passphrase for ./example.ct: 
[-] sudo mkfs.ext4 /dev/mapper/ct_example
mke2fs 1.42.10 (18-May-2014)
Creating filesystem with 100352 1k blocks and 25168 inodes
Filesystem UUID: ff340fe5-99da-471a-9f6a-375b994c139c
Superblock backups stored on blocks: 
        8193, 24577, 40961, 57345, 73729

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done 

Mapper file /dev/mapper/ct_example already exists, not reopening
[-] mkdir -p ./example
[-] sudo mount /dev/mapper/ct_example ./example
[-] sudo chown 1000:1000 ./example
[*] Created ./example.ct of size 100MB
[*] Open and mounted
```

#### Adding a file in the encryted container, and closing the container

We are creating "example/my_encrypted_file.txt", and closing the container.
Closing the container leaves only "example.ct", the "example/" directory is umounted and removed.

```bash
$ echo "blabla" > example/my_encrypted_file.txt

$ ctmg close example
[-] sudo umount ./example
[-] rmdir ./example
[-] sudo cryptsetup luksClose ct_example
[*] Closed and unmounted ./example
```

#### Reopening the encrypted container

The "example/" directory is re-created and re-mounted from "example.ct".

```bash
$ ctmg open example
[-] sudo cryptsetup luksOpen ./example.ct ct_example
Enter passphrase for ./example.ct: 
[-] mkdir -p ./example
[-] sudo mount /dev/mapper/ct_example ./example
[-] sudo chown 1000:1000 ./example
[*] Opened and mounted ./example

$ more example/my_encrypted_file.txt 
blabla
```
