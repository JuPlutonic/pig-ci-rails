# frozen_string_literal: true

class PigCI::Profiler::SqlActiveRecord < PigCI::Profiler
  def increment!(by: 1)
    @log_value += by
  end
end
