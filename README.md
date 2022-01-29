# Ubuntu iRODS Installer

Script for mostly automating install of iRODS on Ubuntu16-18 from remote or local packages

Demo in docker_iRODS_build subdirectory:

```
docker build -f Dockerfile.427 -t ir427 .
docker run -it ir427
# /start_postgresql_and_irods.sh
```

Note versions of irods >= 4.2.11 are installable via a command such as

```
ubuntu_irods_installer/install.sh -r --i=4.2.11-1~bionic 4
```

where as previously only 4.2.10, etc needed to be specified.
