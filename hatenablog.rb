# frozen_string_literal: true

require 'colorize'
require "hatenablog"

# ------------------------------------------------------------------------------
# utils

def usage(err = false)
  s = <<~USAGE
    Usage:

      #{$PROGRAM_NAME} -h|--help
      #{$PROGRAM_NAME} <path to markdown>
  USAGE
  s = s.chomp.white
  if err
    warn(s)
    exit(1)
  else
    puts(s)
    exit(0)
  end
end

# @param [String] s
def log_error(s)
  warn(s.chomp.red)
end

# @param [String] s
def log_warn(s)
  warn(s.chomp.yellow)
end

# @param [String] s
def log_info(s)
  warn(s.chomp.blue)
end

# @param [String] s
def log_debug(s)
  warn(s.chomp.white)
end

# ------------------------------------------------------------------------------
# cli

# require 'optparse'
# options = {}
# OptionParser.new do |parser|
#   parser.on("-v", "--[no-]verbose", "Run verbosely") do |v|
#     options[:verbose] = v
#   end
# end.parse!

md = ARGV.shift
usage(err = true) if md.nil?
usage(err = false) if %w[-h help --help].include?(md)
unless ARGV.empty?
  log_error("extra argument given: #{ARGV[0]}")
  usage(err = true)
end

# ------------------------------------------------------------------------------
# model

# @attr [String, nil] title
# @attr [String, nil] url
# @attr [[Array<String>], nil] hatena_categories
# @attr [String, nil] hatena_id
# @attr [String, nil] content
class Config
  attr_accessor :title, :url, :hatena_categories, :hatena_id, :content

  def initialize
    @title = nil
    @url = nil
    @hatena_categories = []
    @hatena_id = nil
    @content = nil
  end
end

# ------------------------------------------------------------------------------
# app

config = Config.new

md = File.read(md)
tmp = md[...5] # alleviate RubyMine parser's bug
unless tmp == "<!--\n"
  log_error("line 1: not start with <!-- ; given: #{tmp}")
  exit(1)
end
tmp = nil
config.content = md

# @param [String] key
# @param [String] value
# @param [Config] config
# @return [nil]
def parse_kv(key, value, config)
  log_debug("#{key}: #{value}")
  case key
  when "0file"
  when "0title"
    config.title = value
  when "0url"
    if value.include?('TODO')
      log_debug('skip TODO')
      return
    end
    config.url = value
  when "hatena_categories"
    config.hatena_categories = value.split
  when "hatena_id"
    config.hatena_id = value
  else
    log_warn("skip")
  end
end

i = 2
md[5..].lines.each do |line|
  break if line == "-->\n"
  m = /(\w+): (.+)/.match(line)
  if m.nil?
    log_error("line #{i}: malformed: #{line}")
    exit(1)
  end
  k, v = m[1..2]
  parse_kv(key = k, value = v, config = config)
  i += 1
end
i = nil

# ------------------------------------------------------------------------------
# post
# https://github.com/kymmt90/hatenablog

# @param [String] method
# @param [Config] config
# @return [Boolean] true if yes
def confirm(method, config)
  log_info("title:             #{config.title}")
  log_info("hatena_categories: #{config.hatena_categories}")
  log_info("hatena_id:         #{config.hatena_id}")
  log_info("content:           #{config.content[...50].gsub("\n", '\n')}")
  log_info("                   ... #{config.content[-50..].gsub("\n", '\n')}")
  log_info("#{method}? [y/N]")
  tmp = gets.chomp
  return true if %w[y yes].include?(tmp.downcase)
  false
end

# @param [Hatenablog::BlogEntry] entry
def log_result(entry)
  log_debug("author_name : #{entry.author_name}")
  log_debug("categories  : #{entry.categories}")
  log_debug("content     : #{entry.content[...50].gsub("\n", '\n')}")
  log_debug("edit_uri    : #{entry.edit_uri}")
  log_debug("id          : #{entry.id}")
  log_debug("title       : #{entry.title}")
  log_debug("updated     : #{entry.updated}")
  log_debug("uri         : #{entry.uri}")
  log_info("0url: #{entry.uri}")
  log_info("hatena_id: #{entry.id}")
end

# @param [Hatenablog::Client] blog
# @param [Config] config
# @return [nil]
def post(blog, config)
  unless confirm(method = 'POST', config = config)
    log_warn("not POSTED")
    return
  end

  entry = blog.post_entry(
    config.title,
    config.content,
    config.hatena_categories,
    )
  log_info("POSTED!")
  log_result(entry)
end

# @param [Hatenablog::Client] blog
# @param [Config] config
# @return [nil]
def update(blog, config)
  # id = parse_id(config.url)

  unless confirm(method = 'PUT', config = config)
    log_warn("not PUTTED")
    return
  end

  entry = blog.update_entry(
    config.hatena_id,
    config.title,
    config.content,
    config.hatena_categories,
    )
  log_info("PUTTED!")
  log_result(entry)
end

# tmp = File.join(File.dirname(__FILE__), "config.yml")
tmp = File.join(ENV["HOME"], "qrb/tesrb/src/hatenablog.rb.config.yml")
Hatenablog::Client.create(config_file = tmp) do |blog|
  if config.url.nil?
    post(blog = blog, config = config)
  else
    update(blog = blog, config = config)
  end
end

exit(0)
