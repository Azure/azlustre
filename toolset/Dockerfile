FROM ubuntu:20.04

LABEL publisher="Paul Edwards"

RUN apt update && apt install -y python3 git curl apt-utils makeself zip jq

RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

RUN git clone https://github.com/Azure/azurehpc.git