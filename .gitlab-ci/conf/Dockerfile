# Sample file to create a Docker image including our Drupal codebase.
FROM drupal:11-apache

WORKDIR /opt/drupal

# Remove the Drupal project that comes with the parent image.
RUN rm -rf ..?* .[!.]* *

# Copy application inside the container.
COPY ../ .
