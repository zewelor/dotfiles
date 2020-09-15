Pry.config.editor = 'vim'

def _pry_config
  Pry.config
end

history_file_path = File.expand_path(".pry_history")

# Pry >= 0.13
if _pry_config.respond_to?(:history_file=)
  _pry_config.history_file = history_file_path
else
  _pry_config.history.file = history_file_path
end

# == PLUGINS ===
# amazing_print gem: great syntax colorized printing
# look at ~/.aprc for more settings for amazing_print
begin
  require 'amazing_print'
  # The following line enables amazing_print for all pry output,
  # and it also enables paging
  Pry.config.print = proc {|output, value| Pry::Helpers::BaseHelpers.stagger_output("=> #{value.ai}", output)}

  # If you want amazing_print without automatic pagination, use the line below
  # Pry.config.print = proc { |output, value| output.puts value.ai }
rescue LoadError => err
  puts "gem install amazing_print  # <-- highly recommended"
end
