# Lanti/meanApp
#
# VERSION               1.0.0

FROM mean_node:latest
MAINTAINER Istvan Lantos <info@lantosistvan.com>
LABEL Description="Node.js App" Vendor="Istvan Lantos" Version="1.0"

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

ONBUILD COPY package.json /usr/src/app/
ONBUILD RUN npm install
ONBUILD COPY . /usr/src/app

CMD ["npm", "start"]
