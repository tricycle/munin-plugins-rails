module Munin
  class RailsRequestDuration < RailsPlugin
    def config
      str=<<-CONFIG
        graph_category #{graph_category}
        graph_title Request time
        graph_vlabel Seconds
        graph_args --base 1000 -l 0
        graph_info The minimum, maximum and average request times - railsdoctors.com
      CONFIG
      puts str.gsub(/^\s+/,'')
      actions.each do |k,v|
        puts "#{k}_max.label #{k} max"
        puts "#{k}_average.label #{k} avg"
      end
      exit 0
    end

    def actions
      return @actions if @actions

      actionStr = environment['actions'] || ''
      actions = actionStr.split(';').map do |str|
        graphName, actionStrList = str.split(':',2)
        actionPatterns = actionStrList.split(',').map &:strip
        [graphName.strip, actionPatterns]
      end
      @actions = actions.push(['other', ['.*']])
    end

    def default_vals
      { :max_value => 0,
        :min_value => 1.0/0.0,
        :cumulative => 0,
        :hits => 0}
    end

    def get_action(item, hash)
      actions.each do |name, patterns|
        if patterns.any? {|p| !!item.match(p)}
          return hash[name] ||= default_vals.dup
        end
      end
      raise "Expect the 'other' pattern to catch all"
    end

    # Gather information
    def run
      ensure_log_file

      # Initialize values
      valueHash = Hash.new

      rla = parse_request_log_analyzer_data

      if rla && rla["Request duration"]
        rla["Request duration"].each do |item|
          values = get_action(item[0], valueHash)
          values[:max_value] = item[1][:max] if item[1][:max] > values[:max_value]
          values[:min_value] = item[1][:min] if item[1][:min] < values[:min_value]
          values[:hits] += item[1][:hits]
          values[:cumulative] += item[1][:sum]
        end
      end

      valueHash.each do |k,v|
        hits = v[:hits]
        hits = 1 if v[:hits]==0
        puts "#{k}_max.value #{v[:max_value]}"
        puts "#{k}_average.value #{v[:cumulative] / hits.to_f}"
      end
    end
  end
end
