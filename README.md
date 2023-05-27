# Docker Certbot ACM

```bash
docker build -t certbot-acm .
docker tag certbot-acm lyrasis/certbot-acm:latest
docker push lyrasis/certbot-acm:latest

docker run -it -p 80:80 --rm certbot-acm
```
