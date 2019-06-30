# This subscribes to the ActiveSupport::Notifications and passes it onto our profilers.
class PigCI::ProfilerEngine::Rails < ::PigCI::ProfilerEngine
  def initialize(profilers: nil, reports: nil)
    @profilers = profilers || [
      PigCI::Profiler::Memory.new,
      PigCI::Profiler::InstantiationActiveRecord.new,
      PigCI::Profiler::RequestTime.new,
      PigCI::Profiler::SqlActiveRecord.new
    ]
    @reports = reports || [
      PigCI::Report::Memory.new,
      PigCI::Report::InstantiationActiveRecord.new,
      PigCI::Report::RequestTime.new,
      PigCI::Report::SqlActiveRecord.new
    ]
    @request_captured = false
  end

  def set_request_key_from_payload!(payload)
    @request_key = "#{payload[:method]} #{payload[:controller]}##{payload[:action]}{format:#{payload[:format]}}"
  end

  private

  def attach_listeners!
    ::ActiveSupport::Notifications.subscribe 'start_processing.action_controller' do |name, started, finished, unique_id, payload|
      set_request_key_from_payload!(payload)

      profilers.each(&:reset!)
    end

    ::ActiveSupport::Notifications.subscribe 'instantiation.active_record' do |name, started, finished, unique_id, payload|
      if request_key?
        profilers.select { |profiler| profiler.class == PigCI::Profiler::InstantiationActiveRecord }.each do |profiler|
          profiler.increment!(by: payload[:record_count])
        end
      end
    end

    ::ActiveSupport::Notifications.subscribe 'sql.active_record' do |name, started, finished, unique_id, payload|
      if request_key?
        profilers.select { |profiler| profiler.class == PigCI::Profiler::SqlActiveRecord }.each do |profiler|
          profiler.increment!
        end
      end
    end

    ::ActiveSupport::Notifications.subscribe 'process_action.action_controller' do |name, started, finished, unique_id, payload|
      profilers.each do |profiler|
        profiler.log_request!(request_key)
      end

      request_captured!
      self.request_key = nil
    end
  end
end
