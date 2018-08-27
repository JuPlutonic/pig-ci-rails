class PigCi::Rails
  def self.setup!
    Dir.mkdir(PigCi.tmp_directory) unless File.exists?(PigCi.tmp_directory)

    PigCi::Loggers::Memory.setup!
    PigCi::Loggers::InstantiationActiveRecord.setup!
    PigCi::Loggers::SqlActiveRecord.setup!

    # Attach listeners
    attach_listeners!
  end

  def self.request_key
    @request_key
  end

  def self.request_key=(value)
    @request_key = value
  end

  def self.attach_listeners!
    ::ActiveSupport::Notifications.subscribe "start_processing.action_controller" do |*args|
      event = ActiveSupport::Notifications::Event.new *args

      self.request_key = "#{event.payload[:method]} #{event.payload[:controller]}##{event.payload[:action]}{format:#{event.payload[:format]}}"
      PigCi::Loggers::Memory.start!
      PigCi::Loggers::InstantiationActiveRecord.start!
      PigCi::Loggers::SqlActiveRecord.start!
    end

    ::ActiveSupport::Notifications.subscribe "instantiation.active_record" do |*args|
      if self.request_key
        event = ActiveSupport::Notifications::Event.new *args
        PigCi::Loggers::InstantiationActiveRecord.increment!(by: event.payload[:record_count])
      end
    end

    ::ActiveSupport::Notifications.subscribe "sql.active_record" do |*args|
      if self.request_key
        event = ActiveSupport::Notifications::Event.new *args
        PigCi::Loggers::SqlActiveRecord.increment!
      end
    end

    ::ActiveSupport::Notifications.subscribe "process_action.action_controller" do |*args|
      event = ActiveSupport::Notifications::Event.new *args
      PigCi::Loggers::Memory.append_row(self.request_key)
      PigCi::Loggers::InstantiationActiveRecord.append_row(self.request_key)
      PigCi::Loggers::SqlActiveRecord.append_row(self.request_key)

      PigCi::Loggers::Memory.complete!
      self.request_key = nil
    end
  end

  def self.print_reports!
    [
      PigCi::Reports::Memory,
      PigCi::Reports::InstantiationActiveRecord,
      PigCi::Reports::SqlActiveRecord
    ].collect(&:print!)
  end

  def self.send_reports!
    puts "[PigCi] Sharing stats with your team…"
  end
end
