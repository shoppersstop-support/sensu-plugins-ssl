#! /usr/bin/env ruby
#
#   check-ssl-cert
#
# DESCRIPTION:
#   Check when a SSL certificate will expire.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# USAGE:
#   example commands
#
# NOTES:
#   Does it behave differently on specific platforms, specific use cases, etc
#
# LICENSE:
#   Jean-Francois Theroux <me@failshell.io>
#   Nathan Williams <nath.e.will@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'date'
require 'openssl'
require 'sensu-plugin/check/cli'

#
# Check SSL Cert
#
class CheckSSLCert < Sensu::Plugin::Check::CLI
  option :critical,
         description: 'Numbers of days left',
         short: '-c',
         long: '--critical DAYS',
         required: true

  option :warning,
         description: 'Numbers of days left',
         short: '-w',
         long: '--warning DAYS',
         required: true

  option :pem,
         description: 'Path to PEM file',
         short: '-P',
         long: '--pem PEM'

  option :host,
         description: 'Host to validate',
         short: '-h',
         long: '--host HOST'

  option :port,
         description: 'Port to validate',
         short: '-p',
         long: '--port PORT'

  option :servername,
         description: 'Set the TLS SNI (Server Name Indication) extension',
         short: '-s',
         long: '--servername SERVER'

  def ssl_cert_expiry
    `openssl s_client -servername #{config[:servername]} -connect #{config[:host]}:#{config[:port]} < /dev/null 2>&1 | openssl x509 -enddate -noout`.split('=').last
  end

  def ssl_pem_expiry
    OpenSSL::X509::Certificate.new(File.read config[:pem]).not_after # rubocop:disable Style/NestedParenthesizedCalls
  end

  def validate_opts
    if !config[:pem]
      unknown 'Host and port required' unless config[:host] && config[:port]
    elsif config[:pem]
      unknown 'No such cert' unless File.exist? config[:pem]
    end
    config[:servername] = config[:host] unless config[:servername]
  end

  def run
    validate_opts
    expiry = config[:pem] ? ssl_pem_expiry : ssl_cert_expiry
    days_until = (Date.parse(expiry.to_s) - Date.today).to_i

    if days_until < 0
      critical "Expired #{days_until.abs} days ago"
    elsif days_until < config[:critical].to_i
      critical "#{days_until} days left"
    elsif days_until < config[:warning].to_i
      warning "#{days_until} days left"
    else
      ok "#{days_until} days left"
    end
  end
end
