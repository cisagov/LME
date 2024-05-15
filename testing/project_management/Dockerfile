FROM python:3.9-slim-buster

# Install the necessary dependencies
RUN apt-get update && apt-get install -y \
    git \
    bash

# Clone the github-projects-burndown-chart repository
RUN git clone https://github.com/thehale/github-projects-burndown-chart

# Set the working directory to the cloned repository
WORKDIR /github-projects-burndown-chart

# Install the required Python packages
RUN pip install --no-cache-dir -r requirements.txt

# Set the entrypoint or command to run the Python script
#ENTRYPOINT ["python", "burndown_chart.py"]
CMD ["tail", "-f", "/dev/null"]