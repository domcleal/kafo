require 'acceptance/test_helper'

module Kafo
  describe 'kafo-configure' do
    before do
      generate_installer
      add_manifest
    end

    describe '--help' do
      it 'includes usage and basic params' do
        code, out, err = run_command 'bin/kafo-configure --help'
        code.must_equal 0
        out.must_include "Usage:"
        out.must_include "kafo-configure [OPTIONS]"
        out.must_match /--testing-version\s*some version number \(default: nil\)/
        out.wont_include "--testing-db-type"
      end
    end

    describe '--full-help' do
      it 'includes all params' do
        code, out, err = run_command 'bin/kafo-configure --full-help'
        code.must_equal 0
        out.must_include "Usage:"
        out.must_include "kafo-configure [OPTIONS]"
        out.must_include "== Basic:"
        out.must_match /--testing-version\s*some version number \(default: nil\)/
        out.must_include "== Advanced:"
        out.must_match /--testing-db-type\s*can be mysql or sqlite \(default: nil\)/
      end
    end

    describe 'default args' do
      it 'must create file' do
        code, out, err = run_command 'bin/kafo-configure'
        code.must_equal 0
        File.exist?("#{INSTALLER_HOME}/testing").must_equal true
        File.read("#{INSTALLER_HOME}/testing").must_equal '1.0'
      end

      it 'must fail if validations fail' do
        code, out, err = run_command 'bin/kafo-configure --testing-pool-size=fail'
        code.exitstatus.must_equal 21
        err.must_include 'Parameter testing-pool-size invalid: "fail" is not a valid integer'
        File.exist?("#{INSTALLER_HOME}/testing").must_equal false
      end

      it 'must fail if system checks fail' do
        FileUtils.mkdir "#{INSTALLER_HOME}/checks"
        FileUtils.cp File.expand_path('../../fixtures/checks/fail/fail.sh', __FILE__), "#{INSTALLER_HOME}/checks"
        code, out, err = run_command 'bin/kafo-configure'
        code.exitstatus.must_equal 20
        File.exist?("#{INSTALLER_HOME}/testing").must_equal false
      end
    end

    describe '--noop' do
      it 'must not create file' do
        code, out, err = run_command 'bin/kafo-configure -n'
        code.must_equal 0
        File.exist?("#{INSTALLER_HOME}/testing").must_equal false
      end
    end

    describe 'with parameter argument' do
      it 'must apply and persist value' do
        code, out, err = run_command 'bin/kafo-configure --testing-version 2.0'
        code.must_equal 0
        File.read("#{INSTALLER_HOME}/testing").must_equal '2.0'

        code, out, err = run_command 'bin/kafo-configure'
        code.must_equal 0
        File.read("#{INSTALLER_HOME}/testing").must_equal '2.0'
      end

      describe 'with no-op' do
        it 'must apply but not persist value' do
          File.open("#{INSTALLER_HOME}/testing", 'w') { |f| f.write('3.0') }

          code, out, err = run_command 'bin/kafo-configure -n -v --testing-version 2.0'
          code.must_equal 0
          out.must_match %r{#{Regexp.escape(INSTALLER_HOME)}/testing.*content}
          File.read("#{INSTALLER_HOME}/testing").must_equal '3.0'

          code, out, err = run_command 'bin/kafo-configure'
          code.must_equal 0
          File.read("#{INSTALLER_HOME}/testing").must_equal '1.0'
        end
      end
    end
  end
end
