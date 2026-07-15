# Performance gate for the TextileToMarkdown converter.
#
# Runs the converter against adversarial, real-world-shaped documents that
# have historically triggered pathological regex behavior (catastrophic
# backtracking, quadratic rescanning). Any single case exceeding its budget
# fails the gate. Run this against large inputs whenever preprocessing or
# postprocessing steps change - correctness fixtures are far too small to
# surface superlinear behavior.
#
# Usage: ruby extra/perf_gate.rb   (from a checkout, requires pandoc and the
#        htmlentities gem; does not need Redmine)

require 'set'
require 'benchmark'

lib = File.expand_path('../lib', __dir__)
module RedmineReformat; module Converters; module TextileToMarkdown
  module MarkdownTableFormatter; end
end; end; end
require "#{lib}/redmine_reformat/converters/placeholders"
require "#{lib}/redmine_reformat/converters/textile_to_markdown/markdown_table_formatter/table_formatter"
require "#{lib}/redmine_reformat/converters/textile_to_markdown/pandoc_preprocessing"
require "#{lib}/redmine_reformat/converters/textile_to_markdown/converter"

Ctx = Struct.new(:ref, :to_formatting)
def convert(textile, ref)
  RedmineReformat::Converters::TextileToMarkdown::Converter.new
    .convert(textile, Ctx.new(ref, 'markdown'))
end

BUDGET = 8.0 # seconds per case - generous; pathological cases take minutes+

CASES = {}

# pipe-heavy log paste - historically exponential in the glued-table pre-pass
CASES['log_with_pipes'] = (1..800).map {|i|
  "2021-09-02 11:50:00.#{i} ERROR [T-#{i}] action.Foo - request | id=#{i} | status=FAIL! (code #{i})"
}.join("\n")

# pipe-free log paste
CASES['log_plain'] = (1..800).map {|i|
  "2021-09-02 11:50:00.#{i} ERROR [T-#{i}] action.Foo - something failed! (attempt #{i})"
}.join("\n")

# large mixed wiki page - historically quadratic in the list separator handling
section = "h2. S %d\n\ntext !i%d.png! \"l\":http://x.com/p%d\n\n|_. k |_. v |\n| a%d | 50%% |\n\n* one\n* two\n\n<pre>\ncode %d\n</pre>\n"
CASES['mixed_wiki_400'] = (1..400).map {|i| format(section, i, i, i, i, i) }.join("\n")

# giant table with long multiline cells
CASES['giant_multiline_table'] = ("|_. Name |_. Type |_. Module |_. Purpose |\n" + (1..120).map {|i|
  "| CI stat #{i} | Statistical | CI_MOD#{i} | Measure elapsed transaction time for txn #{i}. Measurements are taken synchronously on the same\nthread on which the transaction call is made. |"
}.join("\n") + "\n\n") * 3

# header-style rows with wiki links and failing tails - backtracking bait for
# the star-dot header detection
CASES['star_dot_wiki_links'] = (1..200).map {|i|
  "|_. col [[Page#{i}|disp]] |*. another [[X|y]] |_. tail without close\n|*. a |_. b | plain#{i} |"
}.join("\n\n")

# long dash runs - backtracking bait for the md separator row detection
CASES['dash_runs'] = (1..200).map {|i|
  "| a#{i} | b |\n|--- --- --- --- --- --- --- --- --- ---#{'-' * (i % 40)}|----|\n| c | d |"
}.join("\n\n")

# bracket/regex-heavy content
CASES['regex_heavy'] = (1..300).map {|i|
  "Match @[A-Z]{1,#{i}}\\d+[^\\s\\|]*@ or +[0-9]{#{i},}[\\[\\]\\{\\}]+ - see \"ref#{i}\":http://ex.com/re_#{i} (50% of cases!)"
}.join("\n\n")

failed = []
CASES.each do |name, textile|
  t = Benchmark.realtime { convert(textile, name) }
  status = t > BUDGET ? 'FAIL' : 'ok  '
  failed << name if t > BUDGET
  puts format("%s %-24s %7dB %6.2fs", status, name, textile.bytesize, t)
  $stdout.flush
end

if failed.empty?
  puts "PERF GATE PASSED"
else
  puts "PERF GATE FAILED: #{failed.join(', ')}"
  exit 1
end
