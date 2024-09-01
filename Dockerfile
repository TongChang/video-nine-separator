FROM jrottenberg/ffmpeg:4.4-ubuntu

WORKDIR /app
COPY /scripts/create-nine-sepalator-video.sh /app/
RUN chmod +x /app/create-nine-sepalator-video.sh && \
    sed -i 's/\r$//' /app/create-nine-sepalator-video.sh

ENTRYPOINT ["/app/create-nine-sepalator-video.sh"]