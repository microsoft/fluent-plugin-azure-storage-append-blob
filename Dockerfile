FROM ruby:latest

WORKDIR /plugin

ADD fluent.conf /fluentd/fluent.conf
ADD . /plugin

RUN gem install bundler && \
    gem install fluentd --no-doc && \
    fluent-gem build fluent-plugin-azure-storage-append-blob.gemspec && \
    fluent-gem install fluent-plugin-azure-storage-append-blob-*.gem

ENTRYPOINT ["fluentd", "-c", "/fluentd/fluent.conf"]
