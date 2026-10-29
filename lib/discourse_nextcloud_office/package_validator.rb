# frozen_string_literal: true

require "zip"
require "nokogiri"

module ::DiscourseNextcloudOffice
  # Structural validation for OOXML and ODF packages.
  #
  # It never extracts files to disk, never executes macros and never resolves
  # external relationships. Archive budgets and deep XML hardening follow in
  # task 2.4; this class already rejects traversal names, duplicates, macros
  # and encrypted containers so a structurally wrong package cannot pass.
  class PackageValidator
    MAX_XML_BYTES = 1024 * 1024
    READ_CHUNK_BYTES = 64 * 1024
    EOCD_SIGNATURE = "PK\x05\x06".b
    CENTRAL_SIGNATURE = "PK\x01\x02".b
    EOCD_MIN_BYTES = 22
    EOCD_SEARCH_BYTES = EOCD_MIN_BYTES + 65_535
    LIMITS = {
      max_entries: 10_000,
      max_entry_bytes: 64 * 1024 * 1024,
      max_total_bytes: 250 * 1024 * 1024,
      max_seconds: 5.0,
      max_central_directory_bytes: 8 * 1024 * 1024,
    }.freeze
    SYMLINK_TYPE = 0o120000
    ODF_MANIFEST_NS = "urn:oasis:names:tc:opendocument:xmlns:manifest:1.0"

    OOXML = {
      "docx" => {
        main: "word/document.xml",
        root: "document",
        content_type:
          "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml",
      },
      "xlsx" => {
        main: "xl/workbook.xml",
        root: "workbook",
        content_type:
          "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml",
      },
      "pptx" => {
        main: "ppt/presentation.xml",
        root: "presentation",
        content_type:
          "application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml",
      },
    }.freeze

    ODF = {
      "odt" => {
        mime: "application/vnd.oasis.opendocument.text",
        body: "text",
      },
      "ods" => {
        mime: "application/vnd.oasis.opendocument.spreadsheet",
        body: "spreadsheet",
      },
      "odp" => {
        mime: "application/vnd.oasis.opendocument.presentation",
        body: "presentation",
      },
    }.freeze

    def self.validate!(source, format:, limits: {}, clock: nil)
      new(source, format: format, limits: limits, clock: clock).validate!
    end

    def initialize(source, format:, limits: {}, clock: nil)
      @source = source
      @format = format
      @limits = LIMITS.merge(limits)
      @clock = clock || -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
    end

    def validate!
      raise invalid_content if !::DiscourseNextcloudOffice::OfficeFormat.upload?(@format)

      zip = open_zip
      started = @clock.call
      validate_entries!(zip, started)
      if OOXML.key?(@format)
        validate_ooxml!(zip)
      else
        validate_odf!(zip)
      end
      true
    rescue ::Zip::Error
      raise invalid_content
    ensure
      zip&.close
    end

    private

    def invalid_content
      ::DiscourseNextcloudOffice::RequestError.new(:invalid_file_content, status: :unsupported_media_type)
    end

    def open_zip
      path = source_path
      raise invalid_content if path.nil? || !File.file?(path) || File.zero?(path)

      ::Zip::File.open(path)
    rescue ::Zip::Error, Errno::ENOENT, Errno::EACCES
      raise invalid_content
    end

    def source_path
      if @source.respond_to?(:tempfile)
        @source.tempfile.path
      elsif @source.respond_to?(:path)
        @source.path.to_s
      elsif @source.is_a?(String)
        @source
      end
    end

    # The raw central directory is authoritative: rubyzip silently collapses
    # duplicate names, so entry names and Unix modes are read from the source.
    def validate_entries!(zip, started)
      records = central_directory
      raise invalid_content if records.empty?

      names = records.map { |record| record[:name] }
      raise invalid_content if names.uniq.length != names.length
      raise invalid_content if zip.entries.length != names.length

      records.each do |record|
        name = record[:name]
        raise invalid_content if !name.valid_encoding?

        invalid =
          name.include?("\0") || name.start_with?("/") || name.include?("\\") ||
            name.split("/").include?("..") || symlink_mode?(record[:mode])
        raise invalid_content if invalid

        normalized = name.downcase
        raise invalid_content if normalized.end_with?("vbaproject.bin", "vbadata.xml")
      end

      raise invalid_content if names.any? { |name| encrypted_entry?(name) }

      enforce_stream_budgets!(zip.entries, started)
    end

    def central_directory
      @central_directory ||= read_central_directory
    end

    def read_central_directory
      path = source_path
      size = File.size(path)
      raise invalid_content if size < EOCD_MIN_BYTES

      tail_length = [size, EOCD_SEARCH_BYTES].min
      tail = read_bytes(path, tail_length, size - tail_length)
      position = tail.rindex(EOCD_SIGNATURE)
      raise invalid_content if position.nil?

      eocd = tail.byteslice(position, EOCD_MIN_BYTES)
      raise invalid_content if eocd.nil? || eocd.bytesize < EOCD_MIN_BYTES

      disk, central_disk, disk_entries, entries, central_size, central_offset = eocd.unpack("@4vvvvVV")
      raise invalid_content if disk != 0 || central_disk != 0 || disk_entries != entries
      raise invalid_content if entries > @limits[:max_entries]
      raise invalid_content if central_size > @limits[:max_central_directory_bytes]
      raise invalid_content if central_size.zero? || central_offset + central_size > size

      parse_central_records(
        read_bytes(path, central_size, central_offset),
        expected: entries,
      )
    end

    def parse_central_records(data, expected:)
      records = []
      offset = 0

      while offset < data.bytesize
        raise invalid_content if data.byteslice(offset, 4) != CENTRAL_SIGNATURE

        header = data.byteslice(offset, 46)
        raise invalid_content if header.nil? || header.bytesize < 46

        name_length, extra_length, comment_length = header.unpack("@28vvv")
        mode = header.unpack1("@38V") >> 16
        name = data.byteslice(offset + 46, name_length)
        raise invalid_content if name.nil? || name.bytesize != name_length

        records << { name: name.force_encoding(Encoding::UTF_8), mode: mode }
        offset += 46 + name_length + extra_length + comment_length
      end

      raise invalid_content if records.length != expected

      records
    end

    def read_bytes(path, length, offset)
      File.open(path, "rb") do |file|
        file.seek(offset)
        data = file.read(length)
        raise invalid_content if data.nil? || data.bytesize != length

        data
      end
    rescue SystemCallError
      raise invalid_content
    end

    def symlink_mode?(mode)
      (mode.to_i & 0o170000) == SYMLINK_TYPE
    end

    def enforce_stream_budgets!(entries, started)
      total_bytes = 0

      entries.each do |entry|
        raise invalid_content if time_exceeded?(started) || entry.directory?

        stream = entry.get_input_stream
        entry_bytes = 0
        while (chunk = stream.read(READ_CHUNK_BYTES))
          entry_bytes += chunk.bytesize
          total_bytes += chunk.bytesize
          if entry_bytes > @limits[:max_entry_bytes] || total_bytes > @limits[:max_total_bytes]
            raise invalid_content
          end
          raise invalid_content if time_exceeded?(started)
        end
      ensure
        stream&.close
      end
    end

    def time_exceeded?(started)
      (@clock.call - started) > @limits[:max_seconds]
    end

    def encrypted_entry?(name)
      name.casecmp?("EncryptionInfo") || name.casecmp?("EncryptedPackage")
    end

    def validate_ooxml!(zip)
      spec = OOXML.fetch(@format)
      types = read_xml(zip, "[Content_Types].xml")
      raise invalid_content if types.root&.name != "Types"
      raise invalid_content if types_text(zip).match?(/macroEnabled/i)

      override =
        types
          .xpath("//*[local-name()='Override']")
          .find { |node| node["PartName"] == "/#{spec[:main]}" }
      raise invalid_content if override.nil? || override["ContentType"] != spec[:content_type]

      rels = read_xml(zip, "_rels/.rels")
      office_rel =
        rels
          .xpath("//*[local-name()='Relationship']")
          .find { |node| node["Type"].to_s.end_with?("/officeDocument") }
      raise invalid_content if office_rel.nil? || normalize_part(office_rel["Target"]) != spec[:main]

      main = read_xml(zip, spec[:main])
      raise invalid_content if main.root&.name != spec[:root]

      validate_main_part!(zip, main)
    end

    def types_text(zip)
      read_raw(zip.find_entry("[Content_Types].xml"))
    end

    def validate_main_part!(zip, main)
      case @format
      when "docx"
        raise invalid_content if main.xpath("//*[local-name()='body']").empty?
      when "xlsx"
        validate_workbook!(zip, main)
      end
    end

    def validate_workbook!(zip, workbook)
      sheets = workbook.xpath("//*[local-name()='sheet']")
      raise invalid_content if sheets.empty?

      rels = read_xml(zip, "xl/_rels/workbook.xml.rels")
      worksheet_rel =
        rels
          .xpath("//*[local-name()='Relationship']")
          .find { |node| node["Type"].to_s.end_with?("/worksheet") }
      raise invalid_content if worksheet_rel.nil?

      part = relationship_part(worksheet_rel["Target"], base: "xl")
      raise invalid_content if part.nil? || zip.find_entry(part).nil?

      sheet = read_xml(zip, part)
      raise invalid_content if sheet.root&.name != "worksheet"
    end

    def validate_odf!(zip)
      spec = ODF.fetch(@format)
      first = zip.entries.first
      mime_entry = zip.find_entry("mimetype")
      invalid =
        first.nil? || first.name != "mimetype" || mime_entry.nil? ||
          mime_entry.compression_method != ::Zip::Entry::STORED ||
          read_raw(mime_entry) != spec[:mime]
      raise invalid_content if invalid

      manifest_text = read_raw(zip.find_entry("META-INF/manifest.xml"))
      raise invalid_content if manifest_text.match?(/encryption-data/i)

      manifest = parse_xml(manifest_text)
      raise invalid_content if manifest.root&.name != "manifest"
      raise invalid_content if !manifest_root_matches?(manifest, spec[:mime])
      raise invalid_content if !manifest_lists_content?(manifest)

      content = read_xml(zip, "content.xml")
      raise invalid_content if content.root&.name != "document-content"

      body = content.xpath("//*[local-name()='body']").first
      body_children = body&.element_children&.map(&:name) || []
      raise invalid_content if !body_children.include?(spec[:body])
    end

    def manifest_root_matches?(manifest, mime)
      manifest
        .xpath("//*[local-name()='file-entry']")
        .any? { |node| attribute(node, "full-path") == "/" && attribute(node, "media-type") == mime }
    end

    def manifest_lists_content?(manifest)
      manifest
        .xpath("//*[local-name()='file-entry']")
        .any? { |node| attribute(node, "full-path") == "content.xml" }
    end

    def attribute(node, name)
      node.xpath("@*[local-name()='#{name}']").first&.value
    end

    def relationship_part(target, base:)
      value = target.to_s
      return nil if value.empty? || value.include?("..") || value.include?("\\")

      value = value.sub(%r{\A/}, "")
      value.start_with?("#{base}/") ? value : "#{base}/#{value}"
    end

    def normalize_part(target)
      target.to_s.sub(%r{\A/}, "")
    end

    def read_xml(zip, name)
      entry = zip.find_entry(name)
      raise invalid_content if entry.nil?

      parse_xml(read_raw(entry))
    rescue ::Nokogiri::XML::SyntaxError
      raise invalid_content
    end

    def parse_xml(data)
      raise invalid_content if data.match?(/<!DOCTYPE|<!ENTITY/i)

      ::Nokogiri::XML(data) { |config| config.strict.nonet }
    rescue ::Nokogiri::XML::SyntaxError
      raise invalid_content
    end

    def read_raw(entry)
      raise invalid_content if entry.nil? || (entry.size && entry.size > MAX_XML_BYTES)

      stream = entry.get_input_stream
      data = stream.read(MAX_XML_BYTES + 1)
      raise invalid_content if data.nil? || data.bytesize > MAX_XML_BYTES

      data
    ensure
      stream&.close
    end
  end
end
