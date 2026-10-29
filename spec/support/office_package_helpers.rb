# frozen_string_literal: true

require "zip"
require "tmpdir"
require "fileutils"

module OfficePackageHelpers
  FIXTURE_DIRECTORY = File.expand_path("../fixtures/office", __dir__)

  def office_fixture_path(name)
    File.join(FIXTURE_DIRECTORY, name)
  end

  def package_entries(fixture_name)
    entries = {}
    ::Zip::File.open(office_fixture_path(fixture_name)) do |zip|
      zip.entries.each { |entry| entries[entry.name] = entry.get_input_stream.read }
    end
    entries
  end

  def build_office_package(entries, stored: [])
    @office_package_dir ||= Dir.mktmpdir("office-package")
    @office_package_index = (@office_package_index || 0) + 1
    path = File.join(@office_package_dir, "package-#{@office_package_index}.zip")

    ::Zip::OutputStream.open(path) do |zip|
      entries.each do |name, content|
        method = stored.include?(name) ? ::Zip::Entry::STORED : ::Zip::Entry::DEFLATED
        entry = ::Zip::Entry.new("", name, time: Time.utc(2026, 1, 1), compression_method: method)
        zip.put_next_entry(entry)
        zip.write(content)
      end
    end

    path
  end

  def modified_office_package(fixture_name, add: {}, replace: {})
    entries = package_entries(fixture_name)
    entries.merge!(add)
    entries.merge!(replace) { |_key, _old, new_value| new_value }
    build_office_package(entries, stored: ["mimetype"])
  end

  # Builds a raw stored-only ZIP so specs can express structures rubyzip
  # refuses to write (symlink modes, duplicate names, traversal names).
  def build_raw_zip(entries, filename: "raw-#{SecureRandom.hex(4)}.zip")
    @office_package_dir ||= Dir.mktmpdir("office-package")
    path = File.join(@office_package_dir, filename)

    locals = +"".b
    centrals = +"".b

    entries.each do |entry|
      data = entry.fetch(:data, "").b
      name = entry.fetch(:name).b
      crc = Zlib.crc32(data)
      offset = locals.bytesize
      locals << [
        0x04034b50, 20, 0, 0, 0, 0x21, crc, data.bytesize, data.bytesize, name.bytesize, 0,
      ].pack("VvvvvvVVVvv") << name << data
      centrals << [
        0x02014b50, 0x0314, 20, 0, 0, 0, 0x21, crc, data.bytesize, data.bytesize, name.bytesize,
        0, 0, 0, 0, entry.fetch(:mode, 0o100644) << 16, offset,
      ].pack("VvvvvvvVVVvvvvvVV") << name
    end

    eocd =
      [0x06054b50, 0, 0, entries.size, entries.size, centrals.bytesize, locals.bytesize, 0].pack(
        "VvvvvVVv",
      )

    File.binwrite(path, locals + centrals + eocd)
    path
  end

  def empty_office_file
    @office_package_dir ||= Dir.mktmpdir("office-package")
    path = File.join(@office_package_dir, "empty.bin")
    File.binwrite(path, "")
    path
  end

  def cleanup_office_packages
    FileUtils.remove_entry(@office_package_dir) if @office_package_dir
    @office_package_dir = nil
  end
end
