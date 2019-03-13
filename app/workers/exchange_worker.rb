class ExchangeWorker

  include Sidekiq::Worker
  include Sidekiq::Status::Worker

  sidekiq_options queue: :default, retry: false, backtrace: true

  def expiration
    @expiration = 60 * 60 * 24 * 1 # 1 day
  end

  def perform(file_path)

    # Задача остановлена
    return if cancelled?

    ::VoshodAvtoExchange::Manager.run(

      file_path: file_path,

      init_clb: ->(msg) {
        at(0, msg)
      },

      start_clb: ->(req_total, msg) {
        total(req_total)
        at(0, msg)
      },

      process_clb: ->(index, msg) {
        at(index, msg)
      },

      completed_clb: ->(req_total, msg) {
        at(req_total, msg)
      }

    )

    rescue Exception => ex
      ::Rails.logger.warn(ex)

    ensure
      ::SidekiqManager.close(self.jid)

  end # perform

  def cancelled?
    ::Sidekiq.redis {|c| c.exists("cancelled-#{jid}") }
  end

end # ExchangeWorker
