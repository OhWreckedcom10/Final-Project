FROM python:3.11-alpine

WORKDIR /app

RUN python -m pip install --no-cache-dir --upgrade pip
RUN python -m pip install --no-cache-dir flask
RUN python -c "import flask; print(flask.__version__)"

COPY app/app.py /app/app.py

EXPOSE 5000

CMD ["python", "/app/app.py"]