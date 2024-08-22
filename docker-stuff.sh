source .env
docker-compose down
docker-compose build
docker-compose up -d
docker logs -f labby_backend_1
#docker logs -f labby_teamsbot_1