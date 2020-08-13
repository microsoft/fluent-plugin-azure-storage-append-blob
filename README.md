# fluent-plugin-azure-storage-append-blob

[Fluentd](https://fluentd.org/) out plugin to do something.

Azure Storage Append Blob output plugin buffers logs in local file and uploads them to Azure Storage Append Blob periodically.

## Installation

### RubyGems

    gem install fluent-plugin-azure-storage-append-blob

### Bundler

Add following line to your Gemfile:

    gem "fluent-plugin-azure-storage-append-blob"

And then execute:

    bundle

## Configuration

    <match pattern>
      type azure-storage-append-blob

      azure_storage_account             <your azure storage account>
      azure_storage_access_key          <your azure storage access key> # leave empty to use MSI
      azure_storage_sas_token           <your azure storage sas token> # leave empty to use MSI
      azure_imds_api_version            <Azure Instance Metadata Service API Version> # only used for MSI
      azure_token_refresh_interval      <refresh interval in min> # only used for MSI
      azure_container                   <your azure storage container>
      auto_create_container             true
      path                              logs/
      azure_object_key_format           %{path}%{time_slice}_%{index}.log
      time_slice_format                 %Y%m%d-%H
      # if you want to use %{tag} or %Y/%m/%d/ like syntax in path / azure_blob_name_format,
      # need to specify tag for %{tag} and time for %Y/%m/%d in <buffer> argument.
      <buffer tag,time>
        @type file
        path /var/log/fluent/azurestorageappendblob
        timekey 120 # 2 minutes
        timekey_wait 60
        timekey_use_utc true # use utc
      </buffer>
    </match>

### `azure_storage_account` (Required)

Your Azure Storage Account Name. This can be retrieved from Azure Management portal.

### `azure_storage_access_key` or `azure_storage_sas_token` (Either required or both empty to use MSI)

Your Azure Storage Access Key (Primary or Secondary) or shared access signature (SAS) token.
This also can be retrieved from Azure Management portal.

If both are empty, the plugin will use the local Managed Identity endpoint to obtain a token for the target storage account.

### `azure_imds_api_version` (Optional, only for MSI)

Default: 2019-08-15

The Instance Metadata Service is used during the OAuth flow to obtain an access token. This API is versioned and specifying the version is mandatory.

See [here](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/instance-metadata-service#versioning) for more details.

### `azure_token_refresh_interval` (Optional, only for MSI)

Default: 60 (1 hour)

When using MSI, the initial access token needs to be refreshed periodically.

### `azure_container` (Required)

Azure Storage Container name

### `auto_create_container`

This plugin creates the Azure container if it does not already exist exist when you set 'auto_create_container' to true.
The default value is `true`

### `azure_object_key_format`

The format of Azure Storage object keys. You can use several built-in variables:

- %{path}
- %{time_slice}
- %{index}

to decide keys dynamically.

%{path} is exactly the value of *path* configured in the configuration file. E.g., "logs/" in the example configuration above.
%{time_slice} is the time-slice in text that are formatted with *time_slice_format*.
%{index} is used only if your blob exceed Azure 50000 blocks limit per blob to prevent data loss. Its not required to use this parameter.

The default format is "%{path}%{time_slice}-%{index}.log".

For instance, using the example configuration above, actual object keys on Azure Storage will be something like:

    "logs/20130111-22-0.log"
    "logs/20130111-23-0.log"
    "logs/20130112-00-0.log"

With the configuration:

    azure_object_key_format %{path}/events/ts=%{time_slice}/events.log
    path log
    time_slice_format %Y%m%d-%H

You get:

    "log/events/ts=20130111-22/events.log"
    "log/events/ts=20130111-23/events.log"
    "log/events/ts=20130112-00/events.log"

The [fluent-mixin-config-placeholders](https://github.com/tagomoris/fluent-mixin-config-placeholders) mixin is also incorporated, so additional variables such as %{hostname}, etc. can be used in the `azure_object_key_format`. This is useful in preventing filename conflicts when writing from multiple servers.

    azure_object_key_format %{path}/events/ts=%{time_slice}/events-%{hostname}.log

### `time_slice_format`

Format of the time used in the file name. Default is '%Y%m%d'. Use '%Y%m%d%H' to split files hourly.

### Run tests

    gem install bundler
    bundle install
    bundle exec rake test


### Test Fluentd

1. Create Storage Account and VM with enabled MSI
2. Setup Docker ang Git
3. SSH into VM
4. Download this repo
   ```
   git clone https://github.com/microsoft/fluent-plugin-azure-storage-append-blob.git
   cd fluent-plugin-azure-storage-append-blob
   ```
5. Build Docker image
   `docker build -t fluent .`
6. Run Docker image with different set of parameters:

    1. `STORAGE_ACCOUNT`: required, name of your storage account
    2. `STORAGE_ACCESS_KEY`: storage account access key
    3. `STORAGE_SAS_TOKEN`: storage sas token with enough permissions for the plugin

    You need to specify `STORAGE_ACCOUNT` and one of auth ways. If you run it from VM with MSI,
    just `STORAGE_ACCOUNT` is required. Keep in mind, there is no way to refresh MSI Token, so
    ensure you setup proper permissions first.

    ```bash
    docker run -it -e STORAGE_ACCOUNT=<storage> -e STORAGE_ACCESS_KEY=<key> fluent
    ```

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit [https://cla.microsoft.com](https://cla.microsoft.com).

When you submit a pull request, a CLA-bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., label, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
