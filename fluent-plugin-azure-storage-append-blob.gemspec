lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name = 'fluent-plugin-azure-storage-append-blob'
  spec.version = '0.2.1'
  spec.authors = ['Microsoft Corporation']
  spec.email = ['']

  spec.summary = 'Azure Storage Append Blob output plugin for Fluentd event collector'
  spec.description = 'Fluentd plugin to upload logs to Azure Storage append blobs.'
  spec.homepage = 'https://github.com/Microsoft/fluent-plugin-azure-storage-append-blob'
  spec.license = 'MIT'

  test_files, files = `git ls-files -z`.split("\x0").partition do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.files = files
  spec.executables = files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files = test_files
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'test-unit', '~> 3.0'
  spec.add_runtime_dependency 'azure-storage-blob', '~> 2.0'
  spec.add_runtime_dependency 'fluentd', ['>= 0.14.10', '< 2']
end
