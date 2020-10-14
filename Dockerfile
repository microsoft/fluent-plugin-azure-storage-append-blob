FROM ruby:latest

WORKDIR /plugin

ADD . /plugin

RUN gem install bundler && \
    gem install fluentd --no-doc && \
    fluent-gem build fluent-plugin-azure-storage-append-blob.gemspec && \
    fluent-gem install fluent-plugin-azure-storage-append-blob-*.gem

RUN echo "<source>\n\
  @type sample\n\
  sample {\"hello\":\"world\"}\n\
  tag pattern\n\
</source>\n\
<match pattern>\n\
  @type azure-storage-append-blob\n\
  azure_storage_account             \"#{ENV['STORAGE_ACCOUNT']}\"\n\
  azure_storage_access_key          \"#{ENV['STORAGE_ACCESS_KEY']}\"\n\
  azure_storage_connection_string   \"#{ENV['STORAGE_CONNECTION_STRING']}\"\n\
  azure_storage_sas_token           \"#{ENV['STORAGE_SAS_TOKEN']}\"\n\
  azure_container                   fluentd\n\
  auto_create_container             true\n\
  path                              logs/\n\
  azure_object_key_format           %{path}%{time_slice}_%{index}.log\n\
  time_slice_format                 %Y%m%d-%H\n\
  <buffer tag,time>\n\
    @type file\n\
    path /var/log/fluent/azurestorageappendblob\n\
    timekey 120 # 2 minutes\n\
    timekey_wait 60\n\
    timekey_use_utc true # use utc\n\
  </buffer>\n\
</match>" > /plugin/fluent.conf

ENTRYPOINT ["fluentd", "-c", "fluent.conf"]
