require 'test_helper'

module Kafo
  describe Param do
    let(:mod) { nil }
    let(:param) { Param.new(mod, 'test', 'Optional[String]') }

    let(:with_params) { param.tap { |p| p.manifest_default = '$mod::params::test' } }
    let(:with_undef) { param.tap { |p| p.manifest_default = :undef } }
    let(:with_unset) { param.tap { |p| p.manifest_default = 'UNSET' } }
    let(:with_value) { param.tap { |p| p.manifest_default = '42' } }

    describe "#visible?" do
      describe "without condition" do
        specify { param.must_be :visible? }
      end

      describe "with true condition" do
        before { param.condition = 'true' }
        specify { param.must_be :visible? }
      end

      describe "with false condition" do
        before { param.condition = 'false' }
        specify { param.wont_be :visible? }
      end

      describe "with context" do
        let(:context) { [Param.new(nil, 'context', 'String').tap { |p| p.value = true }] }
        before { param.condition = '$context' }
        specify { param.visible?(context).must_equal true }
      end
    end

    describe "#condition_value" do
      before { param.value = 'tester' }
      specify { param.condition_value.must_be_kind_of String }
    end

    describe "#default" do
      specify { with_params.default.must_be_nil }
      specify { with_params.tap { |p| p.default = 'test' }.default.must_equal 'test' }
      specify { with_value.default.must_equal '42' }
    end

    describe "#default=" do
      specify { with_params.tap { |p| p.default = 'test' }.default.must_equal 'test' }
      specify { with_params.tap { |p| p.default = :undef }.default.must_be_nil }
      specify { with_params.tap { |p| p.default = 'UNSET' }.default.must_be_nil }
    end

    describe "#dump_default_needed?" do
      specify { with_params.dump_default_needed?.must_equal true }
      specify { with_undef.dump_default_needed?.must_equal false }
      specify { with_unset.dump_default_needed?.must_equal false }
      specify { with_value.dump_default_needed?.must_equal false }
    end

    describe "group" do
      it "should return empty array by default" do
        param.groups.must_equal []
      end

      describe "when nil was set" do
        before { param.groups = nil }
        specify { param.groups.must_equal [] }
      end

      describe "groups were set" do
        before { param.groups = [ ParamGroup.new('one'), ParamGroup.new('two') ] }
        let(:group_names) { param.groups.map(&:name) }
        specify { group_names.must_include 'one' }
        specify { group_names.must_include 'two' }
      end
    end

    describe "#manifest_default=" do
      specify { with_params.tap { |p| p.manifest_default = 'test' }.manifest_default.must_equal 'test' }
      specify { with_params.tap { |p| p.manifest_default = :undef }.manifest_default.must_be_nil }
      specify { with_params.tap { |p| p.manifest_default = 'UNSET' }.manifest_default.must_be_nil }
    end

    describe "#manifest_default_params_variable" do
      specify { with_params.manifest_default_params_variable.must_equal 'mod::params::test' }
      specify { with_value.manifest_default_params_variable.must_be_nil }
      specify { with_undef.manifest_default_params_variable.must_be_nil }
      specify { with_unset.manifest_default_params_variable.must_be_nil }
    end

    describe "#valid?" do
      let(:mod) do
        mod = MiniTest::Mock.new
        mod.expect(:validations, validations.dup) { |args| args == [param] }
        mod
      end

      describe "with no validations" do
        let(:validations) { [] }
        specify { param.valid?.must_equal true }
      end

      describe "with no validation functions, but data type validation" do
        let(:validations) { [] }
        before { param.value = 1 }
        specify { param.valid?.must_equal false }
        specify { param.tap { |p| p.valid? }.validation_errors.must_equal ['1 is not a valid string'] }
      end

      describe "with a passing validation" do
        before { param.value = 'foo' }
        let(:validations) do
          [create_validation('validate_string', ['$test'])]
        end
        specify { param.valid?.must_equal true }
      end

      describe "with a failing validation" do
        before { param.value = 'foo' }
        let(:validations) do
          [create_validation('validate_integer', ['$test']),
           create_validation('validate_string', ['$test'])]
        end
        specify { param.valid?.must_equal false }
        specify { param.tap { |p| p.valid?}.validation_errors.must_equal ['"foo" is not a valid integer'] }
      end

      describe "with validation on multiple parameters" do
        before { param.value = 'foo' }
        let(:validations) do
          [create_validation('validate_string', ['$extra', '$test'])]
        end
        specify do
          v = MiniTest::Mock.new
          v.expect(:send, true, ['validate_string', ['foo']])
          v.expect(:errors, [])
          Validator.stub(:new, v) do
            param.valid?.must_equal true
          end
        end
      end

      describe "with validate_integer" do
        before { param.value = '2' }
        let(:validations) do
          [create_validation('validate_integer', ['$test', '3', '1'])]
        end
        specify { param.valid?.must_equal true }
      end

      describe "with validate_integer and undef arguments" do
        before { param.value = '2' }
        let(:validations) do
          [create_validation('validate_integer', ['$test', :undef, '1'])]
        end
        specify { param.valid?.must_equal true }
      end

      describe "with validate_re" do
        before { param.value = 'foo' }
        let(:validations) do
          [create_validation('validate_re', ['$test', '^foo$'])]
        end
        specify { param.valid?.must_equal true }
      end

      describe "with Puppet parser" do
        before { param.value = '5' }
        let(:validations) do
          TestParser.new(BASIC_MANIFEST).parse(nil)[:validations].select do |v|
            v.arguments.map(&:to_s).include?('$pool_size')
          end
        end
        let(:param) { Param.new(mod, 'pool_size', 'String') }
        specify { param.valid?.must_equal true }
      end

      describe "validate_re with Puppet parser, array argument and message" do
        let(:manifest) do
          BASIC_MANIFEST.
            sub(/(validate)/, %{validate_re($db_type, ["^mysql$", "^sqlite$"], "invalid $db_type DB type")\n\\1}).
            sub('class testing', 'class testing_re')
        end
        let(:validations) do
          TestParser.new(manifest).parse(nil)[:validations].select do |v|
            v.arguments.map(&:to_s).include?('$db_type')
          end
        end
        let(:param) { Param.new(mod, 'db_type', 'String') }
        specify { param.value = 'sqlite'; param.valid?.must_equal true }

        next if Gem::Specification.find_all_by_name('puppet').sort_by(&:version).last.version >= Gem::Version.new('4.0.0')

        specify do
          param.value = 'wrong'
          logger = MiniTest::Mock.new
          logger.expect(:error, true, ['Validation error: invalid wrong DB type'])
          KafoConfigure.stub(:logger, logger) { param.valid?.must_equal false }
        end
      end

      describe "with manifest default value needing typecasting" do
        let(:param) { Param.new(mod, 'test', 'Integer') }
        let(:validations) { [] }
        before { param.manifest_default = '2' }
        specify { param.valid?.must_equal true }
        specify { param.value.must_equal 2 }
      end

      describe "with dumped default value needing typecasting" do
        let(:param) { Param.new(mod, 'test', 'Integer') }
        let(:validations) { [] }
        before do
          param.manifest_default = '$mod::params::test'
          param.default = '2'
        end
        specify { param.valid?.must_equal true }
        specify { param.value.must_equal 2 }
      end

      private

      def create_validation(function, function_args)
        validation = MiniTest::Mock.new
        validation.expect(:clone, validation)
        3.times { validation.expect(:name, function) }
        2.times { validation.expect(:arguments, function_args) }
        validation
      end
    end

    describe '#set_default_from_dump' do
      specify { with_params.tap { |p| p.set_default_from_dump({}) }.default.must_be_nil }
      specify { with_params.tap { |p| p.set_default_from_dump({'mod::params::test' => '42'}) }.default.must_equal '42' }
      specify { with_params.tap { |p| p.set_default_from_dump({'mod::params::test' => :undef}) }.default.must_be_nil }
      specify { with_value.tap { |p| p.set_default_from_dump({'42' => 'fail'}) }.default.must_equal '42' }
    end

    describe '#unset_value' do
      let(:unset) { param.tap { |p| p.unset_value } }
      specify do
        param.manifest_default = 'def'
        param.value = 'val'
        unset.value.must_equal 'def'
      end
    end

    describe '#value=' do
      specify { param.tap { |p| p.value = 'foo' }.value.must_equal 'foo' }
      specify { param.tap { |p| p.value = 'foo' }.value_set.must_equal true }
      specify { param.tap { |p| p.value = 'UNDEF' }.value.must_be_nil }
      specify { param.tap { |p| p.value = 'UNDEF' }.value_set.must_equal true }
      specify { param.tap { |p| p.value = ::HighLine::String('foo') }.value.must_equal 'foo' }
      specify { param.tap { |p| p.value = ::HighLine::String('foo') }.value.class.must_equal ::String }
      specify { param.tap { |p| p.value = [::HighLine::String('foo')] }.value.must_equal ['foo'] }
      specify { param.tap { |p| p.value = [::HighLine::String('foo')] }.value.first.class.must_equal ::String }
      specify { param.tap { |p| p.value = {::HighLine::String('foo') => ::HighLine::String('bar')} }.value.must_equal({'foo' => 'bar'}) }
      specify { param.tap { |p| p.value = {::HighLine::String('foo') => ::HighLine::String('bar')} }.value.keys.first.class.must_equal ::String }
      specify { param.tap { |p| p.value = {::HighLine::String('foo') => ::HighLine::String('bar')} }.value.values.first.class.must_equal ::String }
    end
  end
end
