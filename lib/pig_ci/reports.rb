require 'terminal-table'

class PigCi::Reports
  def self.print!
    puts "[PigCI] #{I18n.t('.name', scope: i18n_scope)}:\n"
    table = Terminal::Table.new headings: column_keys.collect(&:to_s).collect(&:humanize) do |t|
      aggregated_data.each do |data|
        t << column_keys.collect {|key| data[key] }
      end
    end
    puts table
    puts "\n"
  end

  def self.save!
    historical_data

    @historical_data[PigCi.finish_time] ||= {}
    @historical_data[PigCi.finish_time][i18n_key] = last_run_data

    File.write(output_file, @historical_data.to_json)
  end

  def self.last_run_data
    @last_run_data = {}

    File.foreach(log_file) do |f|
      key, value = f.strip.split('|')
      value = value.to_i

      @last_run_data[key] ||= {
        key: key,
        max: value,
        min: value,
        mean: 0,
        total: 0,
        number_of_requests: 0
      }
      @last_run_data[key][:max] = value if value > @last_run_data[key][:max]
      @last_run_data[key][:min] = value if value < @last_run_data[key][:min]
      @last_run_data[key][:total] += value
      @last_run_data[key][:number_of_requests] += 1
      @last_run_data[key][:mean] = @last_run_data[key][:total] / @last_run_data[key][:number_of_requests]
    end

    @last_run_data.collect{ |k,d| d }.sort_by { |k| k[:max] * -1 }
  end

  def self.aggregated_data
    historical_data[PigCi.finish_time][i18n_key].collect do |data|
      previous_run_data = previous_run_data_for_key(data[:key]) || data

      data[:max_change] = "#{(( BigDecimal(previous_run_data[:max]) / BigDecimal(data[:max]) ) - 1).round(4)}%"
      data
    end
  end

  def self.previous_run_data_for_key(key)
    previous_run_keys.each do |previous_run_key|
      historical_data[previous_run_key][i18n_key.to_sym].each do |raw_previous_run_data|
        return raw_previous_run_data if raw_previous_run_data[:key] == key
      end
    end
    nil
  end

  def self.previous_run_keys
    @previous_run_keys ||= historical_data.keys.reject { |key| key == PigCi.finish_time }.sort.reverse
  end

  def self.historical_data
    @historical_data ||= if File.exists? output_file
      JSON.parse(File.open(output_file, 'r').read, symbolize_names: true)
    else
      {}
    end
  end

  private
  def self.column_keys
    [:key, :max, :min, :mean, :number_of_requests, :max_change]
  end

  def self.log_file
    @log_file ||= PigCi.tmp_directory.join("pig-ci-#{i18n_key}.txt")
  end

  def self.output_file
    @output_file ||= PigCi.output_directory.join("pig-ci-#{i18n_key}.json")
  end

  def self.i18n_key
    @i18n_key ||= name.underscore.split('/').last
  end

  def self.i18n_scope
    @i18n_scope ||= "pig_ci.reports.#{i18n_key}"
  end
end
