FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80
# This invalid instruction will cause the container to crash immediately upon boot
CMD ["invalid-water-executable-error"]
