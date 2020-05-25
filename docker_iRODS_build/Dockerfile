ARG linux_vsn="ubuntu:18.04"
FROM ${linux_vsn}
ARG irods_vsn="4.2.8"
RUN apt update
RUN apt install -y sudo git
WORKDIR /root
RUN git clone http://github.com/d-w-moore/ubuntu_irods_installer
RUN /root/ubuntu_irods_installer/install.sh --w="config-essentials create-db" 0
RUN /root/ubuntu_irods_installer/install.sh --w="add-package-repo add-needed-runtime" 0

# --- fetch and build iRODS ---

RUN mkdir /root/github
WORKDIR /root/github
RUN git clone http://github.com/irods/irods --recursive
RUN git clone http://github.com/irods/irods_client_icommands
RUN for SRC in irods*/; do ( cd $SRC ; git checkout ${irods_vsn} ); done
RUN for SRC in irods*/; do mkdir build__$SRC; done
RUN cd build__irods && /opt/irods-externals/cmake3.1[0-9]*/bin/cmake ../irods -GNinja
RUN cd build__irods && ninja package
RUN /root/ubuntu_irods_installer/install.sh --i=${irods_vsn} --w=basic 4
RUN cd build__irods_client_icommands && /opt/irods-externals/cmake3.1[0-9]*/bin/cmake ../irods_client_icommands -GNinja
RUN cd build__irods_client_icommands && ninja package
RUN /root/ubuntu_irods_installer/install.sh --i=${irods_vsn} --w=basic-skip 4

# --- set up script for command line iRODS install ---

COPY start_postgresql_and_irods.sh /
RUN chmod +x /start_postgresql_and_irods.sh
