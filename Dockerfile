# Use an official Python runtime as a parent image
FROM ubuntu:latest

# Set the working directory in the container
WORKDIR /app

# Copy the contents of the "/scripts" folder into the container at /app
COPY /scripts/ .

RUN apt-get update && \
    apt-get install -y python3 python3-pip

RUN pip3 install psutil

# Install any needed packages specified in requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Set environment variables
ENV MONGO_ADDR=localhost
ENV MONGO_PORT=27017

# Run the script when the container launches
CMD ["python3", "main.py"]
