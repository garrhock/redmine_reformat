# Audit already-converted Redmine content for damage left by a Textile->Markdown
# conversion, i.e. the records behind these redmine_reformat warnings:
#   [WARNING] <ref> - placeholder '...' usage is N at the end
#   [WARNING] <ref> - reformatting MD table failed
#
# It scans the converted text columns for:
#   pua       - leaked private-use-area placeholder characters (hard corruption)
#   breaker   - leaked placeholder breakers `«`/`»` (hard corruption)
#   escpipe   - lines starting with `\|` (broken tables, typically inside {{collapse}})
#   htmlimg   - raw <img> tags (images that fell back to HTML output)
#
# Usage (from the Redmine root directory):
#   bundle exec rails runner plugins/redmine_reformat/extra/audit_conversion_damage.rb
#
# Output: TSV on stdout: class, id, field, problems, url hint where applicable.
# The scan is read-only; nothing is modified.

CHECKS = {
  'pua' => /[\u{E000}-\u{F8FF}]/,
  'breaker' => /[«»]/,
  'escpipe' => /^[[:blank:]]*\\\|/,
  'htmlimg' => /<img\b/i,
}.freeze

def check(text)
  return [] if text.nil? || text.empty?
  CHECKS.select { |_name, re| text =~ re }.keys
end

def report(klass, id, field, problems, hint = nil)
  puts [klass, id, field, problems.join(','), hint].join("\t")
end

SPECS = [
  [Document, [:description]],
  [Issue, [:description], ->(r) { "/issues/#{r.id}" }],
  [Journal, [:notes], ->(r) { "/issues/#{r.journalized_id}#change-#{r.id}" }],
  [Message, [:content]],
  [News, [:description]],
  [Project, [:description]],
  [Comment, [(Comment.new.respond_to?(:content) ? :content : :comments)]],
  [WikiContent, [:text], ->(r) { "/projects/#{r.page.wiki.project.identifier}/wiki/#{r.page.title}" rescue nil }],
  [WikiContent::Version, [:text], ->(r) { "/projects/#{r.page.wiki.project.identifier}/wiki/#{r.page.title}/#{r.version}" rescue nil }],
]

puts %w[class id field problems hint].join("\t")

SPECS.each do |klass, fields, hint|
  klass.find_each do |r|
    fields.each do |field|
      text = begin
        r.send(field)
      rescue StandardError
        next
      end
      problems = check(text)
      next if problems.empty?
      report(klass.name, r.id, field, problems, hint && hint.call(r))
    end
  end
end

# JournalDetail rows for Issue.description edits
JournalDetail.where(property: 'attr', prop_key: 'description')
             .joins(:journal).where(journals: { journalized_type: 'Issue' })
             .find_each do |d|
  [:value, :old_value].each do |field|
    problems = check(d.send(field))
    next if problems.empty?
    report('JournalDetail[Issue.description]', d.id, field, problems,
           "/issues/#{d.journal.journalized_id}#change-#{d.journal_id}")
  end
end

# Formatted custom fields and their journal history
if CustomField.new.respond_to?(:text_formatting)
  CustomField.where(field_format: 'text', text_formatting: 'full').each do |cf|
    CustomValue.where(custom_field_id: cf.id).find_each do |cv|
      problems = check(cv.value)
      report('CustomValue', cv.id, "cf_#{cf.name}", problems) unless problems.empty?
    end
    JournalDetail.where(property: 'cf', prop_key: cf.id.to_s).find_each do |d|
      [:value, :old_value].each do |field|
        problems = check(d.send(field))
        next if problems.empty?
        report('JournalDetail', d.id, "cf_#{cf.name}.#{field}", problems)
      end
    end
  end
end
