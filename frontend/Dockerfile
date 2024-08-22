FROM node:22 as BUILD

ARG VITE_CLIENT_ID
ARG VITE_TENANT_ID
ARG VITE_BASE_URL
ARG VITE_BACKEND_CLIENT_ID


WORKDIR /app

COPY src/package.json /app/package.json

RUN ls -lta

RUN npm install 

COPY src /app

RUN npm run build

FROM nginx:alpine

COPY nginx/default.conf.template /etc/nginx/templates/default.conf.template
COPY --from=BUILD /app/dist /usr/share/nginx/html

EXPOSE 80
