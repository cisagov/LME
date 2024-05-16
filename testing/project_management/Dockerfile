FROM python:3.9-slim-buster

#WORKDIR /lme

# Install the necessary dependencies
RUN apt-get update && apt-get install -y \
    git \
    bash

# This ends up just being at the root of the file system

# Clone the github-projects-burndown-chart repository
RUN git clone https://github.com/thehale/github-projects-burndown-chart && \
    cd github-projects-burndown-chart && \
    pip install --no-cache-dir -r requirements.txt && \
    cp src/github_projects_burndown_chart/config/secrets.json.dist src/github_projects_burndown_chart/config/secrets.json  && \
    cp src/github_projects_burndown_chart/config/config.json.dist src/github_projects_burndown_chart/config/config.json


CMD ["sleep", "infinity"]