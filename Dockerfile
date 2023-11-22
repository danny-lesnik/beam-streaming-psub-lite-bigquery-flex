FROM gcr.io/dataflow-templates-base/python311-template-launcher-base

ENV FLEX_TEMPLATE_PYTHON_PY_FILE="/template/streaming_beam.py"

COPY . /template

RUN apt-get update && apt-get install -y openjdk-11-jdk libffi-dev git && rm -rf /var/lib/apt/lists/* \
    # Upgrade pip and install the requirements.
    && pip install --no-cache-dir --upgrade pip \
    # Include any additional Apache Beam modules as needed.
    && pip install --no-cache-dir -r /template/requirements.txt \
    # Download the requirements to speed up launching the Dataflow job.
    && pip download --no-cache-dir --dest /tmp/dataflow-requirements-cache -r /template/requirements.txt

ENV PIP_NO_DEPS=True

ENTRYPOINT ["/opt/google/dataflow/python_template_launcher"]