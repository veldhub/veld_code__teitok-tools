FROM perl:5.41.6-slim-bookworm
RUN apt update
RUN apt install -y build-essential=12.9 libssl-dev=3.0.15*
RUN cpanm LWP::Simple@6.77
RUN cpanm JSON@4.10
RUN cpanm -fi XML::LibXML@2.0210
WORKDIR /tmp/

