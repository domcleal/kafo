# encoding: UTF-8
require 'kafo/data_type'

module Kafo
  class Validator
    attr_reader :errors

    def initialize(logger = KafoConfigure.logger)
      @errors = []
      @logger = logger
    end

    def validate_absolute_path(args)
      args.each do |arg|
        unless arg.to_s.start_with?('/')
          error "#{arg.inspect} is not an absolute path"
          return false
        end
      end
      return true
    end

    def validate_array(args)
      args.each do |arg|
        unless arg.is_a?(Array)
          error "#{arg.inspect} is not a valid array"
          return false
        end
      end
      return true
    end

    def validate_bool(args)
      args.each do |arg|
        unless arg.is_a?(TrueClass) || arg.is_a?(FalseClass)
          error "#{arg.inspect} is not a valid boolean"
          return false
        end
      end
      return true
    end

    def validate_hash(args)
      args.each do |arg|
        unless arg.is_a?(Hash)
          error "#{arg.inspect} is not a valid hash"
          return false
        end
      end
      return true
    end

    def validate_integer(args)
      value = args[0]
      max = args[1]
      min = args[2]
      int = Integer(value.to_s)
      if min && int < min.to_i
        error "#{value} must be at least #{min}"
        return false
      end
      if max && int > max.to_i
        error "#{value} must be less than #{max}"
        return false
      end
      return true
    rescue TypeError, ArgumentError
      error "#{value.inspect} is not a valid integer"
      return false
    end

    def validate_legacy(args)
      target_type, validation_str, value = *args
      data_type = DataType.new_from_string(target_type)

      dt_errors = []
      dt_valid = data_type.valid?(data_type.typecast(value), dt_errors)

      other_validator = Validator.new
      func_valid = other_validator.respond_to?(validation_str) ? other_validator.send(validation_str, [value]) : true

      if dt_valid && func_valid
        return true
      elsif dt_valid && !func_valid
        @logger.debug("Value #{value.inspect} was accepted as it matches data types, but failed when validated against #{validation_str}")
        other_validator.errors.each { |e| @logger.debug "Legacy validation error: #{e}" }
        return true
      elsif !dt_valid && func_valid
        @logger.warn("Value #{value.inspect} was accepted, but will not be valid in future versions - ensure it matches #{data_type}")
        dt_errors.each { |e| @logger.warn("Validation error: #{e}") }
        return true
      else
        dt_errors.each { |e| error(e) }
        return false
      end
    end

    # Non-standard validation is from theforeman/foreman_proxy module
    def validate_listen_on(args)
      valid_values = ['http', 'https', 'both']
      args.each do |arg|
        unless valid_values.include?(arg)
          error "#{arg.inspect} is not a valid value.  Valid values are: #{valid_values.join(", ")}"
          return false
        end
      end
      return true
    end

    def validate_re(args)
      value = args[0]
      regexes = args[1]
      regexes = [regexes] unless regexes.is_a?(Array)
      message = args[2] || "#{value.inspect} does not match the accepted inputs: #{regexes.join(", ")}"

      if regexes.any? { |rx| value =~ Regexp.compile(rx) }
        return true
      else
        error message
        return false
      end
    end

    def validate_string(args)
      args.each do |arg|
        unless arg.is_a?(String)
          error "#{arg.inspect} is not a valid string"
          return false
        end
      end
      return true
    end

    def method_missing(method, *args, &block)
      if method.to_s.start_with?('validate_')
        @logger.debug "Skipping validation with #{method} as it's not implemented in Kafo"
        return true
      else
        super
      end
    end

    private

    def error(message)
      @errors << message
      @logger.error "Validation error: #{message}"
    end
  end
end
