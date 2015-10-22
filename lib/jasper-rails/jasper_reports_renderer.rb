# -*- encoding: utf-8 -*-
module JasperRails
  class JasperReportsRenderer
    attr_accessor :file_extension
    attr_accessor :options
    attr_accessor :block
    attr_reader :jasper_file, :jrxml_file, :fill_manager, :resource

    def initialize(file, resource)
      @jrxml_file  = fetch_resource(file)
      @jasper_file = jrxml_file.sub(/\.jrxml$/, ".jasper")
      @options     = options
      @resource    = resource
      @fill_manager = Rjb::import 'net.sf.jasperreports.engine.JasperFillManager'
    end

    def fetch_resource(url)
      tempfile = Tempfile.new("teste.jrxml", encoding: "ascii-8bit")
      tempfile << URI.parse(url).read
      tempfile.path
    rescue StandardError => e
      puts e
    end

    def compile
      compile_manager = Rjb::import 'net.sf.jasperreports.engine.JasperCompileManager'
      if !File.exist?(jasper_file) || (File.exist?(jrxml_file) && File.mtime(jrxml_file) > File.mtime(jasper_file))
        compile_manager.compileReportToFile(jrxml_file, jasper_file)
      end
    end

    def fill
      jrxml_utils                 = Rjb::import 'net.sf.jasperreports.engine.util.JRXmlUtils'
      empty_data_source           = Rjb::import 'net.sf.jasperreports.engine.JREmptyDataSource'
      path_query_executer_factory = silence_warnings{Rjb::import 'net.sf.jasperreports.engine.query.JRXPathQueryExecuterFactory'}
      input_source                = Rjb::import 'org.xml.sax.InputSource'
      string_reader               = Rjb::import 'java.io.StringReader'
      hash_map                    = Rjb::import 'java.util.HashMap'
      string                      = Rjb::import 'java.lang.String'

      parameters ||= {}

      jasper_params = hash_map.new
      JasperRails.config[:report_params].each do |k,v|
        jasper_params.put(k, v)
      end

      parameters.each do |key, value|
        jasper_params.put(string.new(key.to_s, 'UTF-8'), parameter_value_of(value))
      end

      # Fill the report
      if resource
        input_source = input_source.new
        input_source.setCharacterStream(string_reader.new(resource.to_xml(JasperRails.config[:xml_options]).to_s))
        data_document = silence_warnings do
          jrxml_utils._invoke('parse', 'Lorg.xml.sax.InputSource;', input_source)
        end

        jasper_params.put(path_query_executer_factory.PARAMETER_XML_DATA_DOCUMENT, data_document)

        generate_jasper_print jasper_params
      else
        fill_manager.fillReport(jasper_file, jasper_params, empty_data_source.new)
      end
    end

    def generate_jasper_print(jasper_params)
      fill_manager.fillReport(jasper_file, jasper_params)
    end

    def render
      begin
        compile
        fill
      rescue StandardError => e
        if e.respond_to? 'printStackTrace'
          ::Rails.logger.error e.message
          e.printStackTrace
        else
          ::Rails.logger.error e.message + "\n " + e.backtrace.join("\n ")
        end
        raise e
      end
    end

    private

    def parameter_value_of(param)
      string = Rjb::import 'java.lang.String'
      if param.class.parent == Rjb
        param
      else
        string.new(param.to_s)
      end
    end
  end
end
