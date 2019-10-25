#---------------------------------------------------------------------------------------------
#  Copyright (c) Microsoft Corporation. All rights reserved.
#  Licensed under the MIT License. See License.txt in the project root for license information.
#--------------------------------------------------------------------------------------------*/

require 'fluent/plugin/output'
require 'azure/storage/blob'
require 'time'
require 'tempfile'

module Fluent
  module Plugin
    class AzureStorageAppendBlobOut < Fluent::Plugin::Output
      Fluent::Plugin.register_output("azure-storage-append-blob", self)

      helpers :formatter, :inject

      DEFAULT_FORMAT_TYPE = "out_file"
  
      config_param :path, :string, :default => ""
      config_param :azure_storage_account, :string, :default => nil
      config_param :azure_storage_access_key, :string, :default => nil, :secret => true
      config_param :azure_storage_sas_token, :string, :default => nil, :secret => true
      config_param :azure_container, :string, :default => nil
      config_param :azure_object_key_format, :string, :default => "%{path}%{time_slice}-%{index}.log"
      config_param :auto_create_container, :bool, :default => true
      config_param :format, :string, :default => DEFAULT_FORMAT_TYPE
      config_param :time_slice_format, :string, :default => '%Y%m%d'
  
      DEFAULT_FORMAT_TYPE = "out_file"
      AZURE_BLOCK_SIZE_LIMIT = 4 * 1024 * 1024 - 1
  
      config_section :format do
        config_set_default :@type, DEFAULT_FORMAT_TYPE
      end
  
      config_section :buffer do
        config_set_default :chunk_keys, ['time']
        config_set_default :timekey, (60 * 60 * 24)
      end
  
      attr_reader :bs
  
      def configure(conf)
        super
  
        @formatter = formatter_create
  
        if @localtime
          @path_slicer = Proc.new {|path|
            Time.now.strftime(path)
          }
        else
          @path_slicer = Proc.new {|path|
            Time.now.utc.strftime(path)
          }
        end
  
        if @azure_container.nil?
          raise ConfigError, 'azure_container is needed'
        end
      end
  
      def multi_workers_ready?
        true
      end
  
      def start
        super
  
        @bs_params = {storage_account_name: @azure_storage_account}

        if !@azure_storage_access_key.nil?
          @bs_params.merge!({storage_access_key: @azure_storage_access_key})
        end

        if !@azure_storage_sas_token.nil?
          @bs_params.merge!({storage_sas_token: @azure_storage_sas_token})
        end

        @bs = Azure::Storage::Blob::BlobService.create(@bs_params)
  
        ensure_container

        @azure_storage_path = ''
        @last_azure_storage_path = ''
        @current_index = 0
      end
  
      def format(tag, time, record)
        r = inject_values_to_record(tag, time, record)
        @formatter.format(tag, time, r)
      end
  
      def write(chunk)
        metadata = chunk.metadata
        tmp = Tempfile.new("azure-")
        begin
          chunk.write_to(tmp)
          tmp.close

          generate_log_name(metadata, @current_index)
          if @last_azure_storage_path != @azure_storage_path
            @current_index = 0
            generate_log_name(metadata, @current_index)
          end

          content = File.open(tmp.path, 'rb') { |file| file.read }

          append_blob(content, metadata)
          @last_azure_storage_path = @azure_storage_path
        ensure
          tmp.unlink
        end
      end
  
      private
      def ensure_container
        if ! @bs.list_containers.find { |c| c.name == @azure_container }
          if @auto_create_container
            @bs.create_container(@azure_container)
          else
            raise "The specified container does not exist: container = #{@azure_container}"
          end
        end
      end

      private
      def generate_log_name(metadata, index)
        time_slice = if metadata.timekey.nil?
                       ''.freeze
                     else
                       Time.at(metadata.timekey).utc.strftime(@time_slice_format)
                     end

        path = @path_slicer.call(@path)
        values_for_object_key = {
          "%{path}" => path,
          "%{time_slice}" => time_slice,
          "%{index}" => index
        }
        storage_path = @azure_object_key_format.gsub(%r(%{[^}]+}), values_for_object_key)
        @azure_storage_path = extract_placeholders(storage_path, metadata)
      end

      private
      def append_blob(content, metadata)
        position = 0
        log.debug "azure_storage_append_blob: append_blob.start: Content size: #{content.length}"
        loop do
          begin
            size = [content.length - position, AZURE_BLOCK_SIZE_LIMIT].min
            log.debug "azure_storage_append_blob: append_blob.chunk: content[#{position}..#{position + size}]"
            @bs.append_blob_block(@azure_container, @azure_storage_path, content[position..position + size])
            position += size
            break if position >= content.length
          rescue Azure::Core::Http::HTTPError => ex
            status_code = ex.status_code

            if status_code == 409 # exceeds azure block limit
              @current_index += 1
              old_azure_storage_path = @azure_storage_path
              generate_log_name(metadata, @current_index)

              # If index is not a part of format, rethrow exception.
              if old_azure_storage_path == @azure_storage_path
                log.warn "azure_storage_append_blob: append_blob: blocks limit reached, you need to use %{index} for the format."
                raise
              end

              log.debug "azure_storage_append_blob: append_blob: blocks limit reached, creating new blob #{@azure_storage_path}."
              @bs.create_append_blob(@azure_container, @azure_storage_path)
            elsif status_code == 404 # blob not found
              log.debug "azure_storage_append_blob: append_blob: #{@azure_storage_path} blob doesn't exist, creating new blob."
              @bs.create_append_blob(@azure_container, @azure_storage_path)
            else
              raise
            end
          end
        end
        log.debug "azure_storage_append_blob: append_blob.complete"
      end

    end
  end
end
