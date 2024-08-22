FROM node:22

WORKDIR /app

COPY src/package.json /app/package.json

RUN npm install

COPY src /app
COPY entry.sh /app/entry.sh

RUN npm run build

EXPOSE 3978

ENTRYPOINT [ "/app/entry.sh" ]
