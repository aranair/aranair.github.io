class ReadingTime < Middleman::Extension
  def initialize(app, options_hash={}, &block)
    super
  end

  helpers do
    def reading_time(input)
      words_per_minute = 130.0

      words = input.split.size
      minutes = (words/words_per_minute).floor
      minutes_label = minutes == 1 ? ' minute' : ' minutes'
      minutes > 0 ? "#{minutes} #{minutes_label}" : 'less than a minute'
    end
  end
end

::Middleman::Extensions.register(:reading_time, ReadingTime)
