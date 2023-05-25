# Docker Certbot ACM

```bash
docker build -t certbot-acm .
docker run -it --rm certbot-acm bash
docker tag certbot-acm lyrasis/certbot-acm:latest
docker push lyrasis/certbot-acm:latest
```
