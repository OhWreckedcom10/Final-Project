FROM python:3.11-alpine AS builder

WORKDIR /app

RUN pip install --no-cache-dir \
    --target=/python \
    flask

COPY app/app.py .

FROM gcr.io/distroless/python3-debian12:latest

WORKDIR /app

COPY --from=builder /python /python
COPY --from=builder /app/app.py .

ENV PYTHONPATH=/python

EXPOSE 5000

CMD ["app.py"]