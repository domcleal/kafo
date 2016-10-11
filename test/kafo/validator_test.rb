require 'test_helper'

DummyParam = Struct.new(:name, :value)

module Kafo
  describe Validator do
    let(:logger) { MiniTest::Mock.new }
    let(:validator) { Validator.new(logger) }
    after { logger.verify }

    describe "#errors" do
      specify do
        logger.expect(:error, true) { true }
        validator.tap { |v| v.validate_string([1]) }.errors.must_equal ["1 is not a valid string"]
      end
    end

    describe "#validate_legacy" do
      specify { validator.validate_legacy(['Integer', 'validate_integer', 1]).must_equal true }
      specify do
        logger.expect(:debug, true, ['Value "foo" was accepted as it matches data types, but failed when validated against validate_integer'])
        logger.expect(:debug, true, ['Legacy validation error: "foo" is not a valid integer'])
        validator.validate_legacy(['Variant[Integer, String]', 'validate_integer', 'foo']).must_equal true
      end
      specify do
        logger.expect(:debug, true, ['Value 5 was accepted as it matches data types, but failed when validated against validate_integer'])
        logger.expect(:debug, true, ['Legacy validation error: 5 must be less than 3'])
        validator.validate_legacy(['Integer', 'validate_integer', 5, [3]]).must_equal true
      end
      specify do
        logger.expect(:warn, true, ['Value ["foo"] was accepted, but will not be valid in future versions - ensure it matches array of integer'])
        logger.expect(:warn, true, ['Validation error: Elements of the array are invalid: "foo" is not a valid integer'])
        validator.validate_legacy(['Array[Integer]', 'validate_array', ['foo']]).must_equal true
      end
      specify do
        logger.expect(:error, true, ['Validation error: "foo" is not a valid integer'])
        validator.validate_legacy(['Integer', 'validate_integer', 'foo']).must_equal false
      end
    end

    describe "#method_missing responds to unknown validation functions" do
      specify do
        logger.expect(:debug, true, ["Skipping validation with validate_unknown_function as it's not implemented in Kafo"])
        validator.validate_unknown_function(['foo']).must_equal true
      end
      specify { Proc.new { validator.unknown_method(['foo']) }.must_raise NoMethodError }
    end

    describe "passing validations" do
      describe "#validate_absolute_path" do
        specify { validator.validate_absolute_path(['/opt']).must_equal true }
        specify { validator.validate_absolute_path(['/opt', '/usr']).must_equal true }
      end

      describe "#validate_array" do
        specify { validator.validate_array([['a','b','c']]).must_equal true }
      end

      describe "#validate_bool" do
        specify { validator.validate_bool([true]).must_equal true }
        specify { validator.validate_bool([false]).must_equal true }
      end

      describe "#validate_hash" do
        specify { validator.validate_hash([{'a' => 'b'}]).must_equal true }
      end

      describe "#validate_integer" do
        specify { validator.validate_integer([1]).must_equal true }
        specify { validator.validate_integer(['1']).must_equal true }

        # maximums
        specify { validator.validate_integer([1, 2]).must_equal true }

        # minimums
        specify { validator.validate_integer([3, nil, 2]).must_equal true }

        # min and max
        specify { validator.validate_integer([3, 5, 2]).must_equal true }
        specify { validator.validate_integer(['3', '5', '2']).must_equal true }
      end

      describe "#validate_listen_on" do
        specify { validator.validate_listen_on(['http']).must_equal true }
        specify { validator.validate_listen_on(['https']).must_equal true }
        specify { validator.validate_listen_on(['both']).must_equal true }
        specify { validator.validate_listen_on(['http', 'https']).must_equal true }
      end

      describe "#validate_re" do
        specify { validator.validate_re(['www.theformean.org', '^.*\.org$']).must_equal true }
        specify { validator.validate_re(["ipmitool", "^(freeipmi|ipmitool|shell)$"]).must_equal true }
        specify { validator.validate_re(["ipmitool", ["^freeipmi$", "^ipmitool$"]]).must_equal true }

        describe "with error message" do
          specify { validator.validate_re(["bar", "^bar$", "Does not match"]).must_equal true }
        end
      end

      describe "#validate_string" do
        specify { validator.validate_string(['foo']).must_equal true }
        specify { validator.validate_string(['foo', 'bar']).must_equal true }
      end
    end

    describe "failing validations" do
      let(:logger) do
        logger = MiniTest::Mock.new
        logger.expect(:error, true) { |args| args.first.start_with?('Validation error: ') }
        logger
      end

      describe "#validate_absolute_path" do
        specify { validator.validate_absolute_path(['./opt']).must_equal false }
      end

      describe "#validate_array" do
        specify { validator.validate_array(['a']).must_equal false }
        specify { validator.validate_array([nil]).must_equal false }
      end

      describe "#validate_bool" do
        specify { validator.validate_bool(['false']).must_equal false }
        specify { validator.validate_bool([0]).must_equal false }
        specify { validator.validate_bool([nil]).must_equal false }
      end

      describe "#validate_hash" do
        specify { validator.validate_hash(['a']).must_equal false }
        specify { validator.validate_hash([nil]).must_equal false }
      end

      describe "#validate_integer" do
        specify { validator.validate_integer(['foo']).must_equal false }
        specify { validator.validate_integer([nil]).must_equal false }

        # maximums
        specify { validator.validate_integer([3, 2]).must_equal false }

        # minimums
        specify { validator.validate_integer([1, nil, 2]).must_equal false }

        # min and max
        specify { validator.validate_integer([1, 5, 2]).must_equal false }
      end

      describe "#validate_listen_on" do
        specify { validator.validate_listen_on(['foo']).must_equal false }
        specify { validator.validate_listen_on([1]).must_equal false }
        specify { validator.validate_listen_on([nil]).must_equal false }
      end

      describe "#validate_re" do
        specify { validator.validate_re(['www.theformean,org', '^.*\.org$']).must_equal false }
        specify { validator.validate_re(["xipmi", "^(freeipmi|ipmitool|shell)$"]).must_equal false }
        specify { validator.validate_re([nil, "^(freeipmi|ipmitool|shell)$"]).must_equal false }
        specify { validator.validate_re(["xipmi", ["^freeipmi$", "^ipmitool$"]]).must_equal false }

        describe "with error message" do
          specify { validator.validate_re(["foo", "^bar$", "Does not match"]).must_equal false }
        end
      end

      describe "#validate_string" do
        specify { validator.validate_string([1]).must_equal false }
        specify { validator.validate_string([1, 'foo']).must_equal false }
        specify { validator.validate_string([nil]).must_equal false }
      end
    end
  end
end
