require 'pstore'
require 'securerandom'

class Task

	attr_accessor :title, :description, :date_due, :category, :key, :hash, :todos

	def initialize(title: "", description: "", category: "", date_due: "", key:, taskmanager:)
		@title = title
		@description = description
		@category = category
		@date_due = date_due
		@key = key
		@taskmanager = taskmanager
	end

	def save
		@todos.save
	end

	def delete
		@taskmanager.delete(self.key)
	end

	def to_hash
		@hash ||= { 
		  key:         @key,
		  title:       @title, 
		  description: @description,
		  category:    @category,
		  date_due:    @date_due 
		}
	end

end

class TaskManager

	attr_accessor :all

	def initialize()
		@all = {}
		@store = PStore.new('tasks.pstore')
	end	

	def new_key
		SecureRandom.hex(10)
	end

	def new_task(title:, description: "", category: "")
		t = Task.new(
				title:       title,
			 	description: description,
			 	category:    category,
			 	key:         new_key,
			 	taskmanager: self
			 	)
		add(t)
	end

	def add(task)
		@all[task.key] = task
	end

	def save
		@store.transaction do
			@all.each do |key, todo|
				@store[key] = todo.to_hash  
			end
		end
	end

	def open
		@all = []
		@store.transaction(true) do
			@store.roots.each do |root|
				t = Task.new(title: @store[root][:title],
							 description: @store[root][:description],
							 category: @store[root][:category],
							 key: @store[root][:key],
							 taskmanager: self)
				self.add(t)
			end
		end
	end

	def delete(key)
		@store.transaction(false) do
			@store.delete(key)
		end
		self.open
	end
end

class Chron

	attr_accessor :date, :args, :year, :month, :day, :hour, :minute

	DAYS_OF_WEEK       = %w[sunday monday tuesday wednesday thursday friday saturday]
	
	MONTHS_FULL        = %w[january february march april may june july august september october november december]
	MONTHS_ABR         = %w[jan feb mar apr may jun jul aug sep oct nov dec]
	MONTHS_NUM         = %w[1 2 3 4 5 6 7 8 9 10 11 12]
	MONTHS_NUM_ALT     = %w[01 02 03 04 05 06 07 08 09 10 11 12]
	MONTHS             = MONTHS_FULL + MONTHS_ABR + MONTHS_NUM + MONTHS_NUM_ALT

	DAYS_NUM           = %w[1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24
			                25 26 27 28 29 30 31]
    DAYS_WITH_SUFF     = %w[1st 2nd 3rd 4th 5th 6th 7th 8th 9th 10th 11th 12th 13th 14th 15th
    					    16th 17th 18th 19th 20th 21st 22nd 23rd 24th 25th 26th 27th 28th
    					    29th 30th 31st]
	DAYS_NUM_ALT       = %w[01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19
			                20 21 22 23 24 25 26 27 28 29 30 31]
	DAYS_TEXT	       = %w[first second third fourth fifth sixth seventh eighth nineth twentythree
						    eleventh twelth thirteenth fourteenth fifteenth sixteenth seventeenth eighteenth
						    nineteenth twentith twentyfirst twentysecond twentythird twentyfourth twentyfifth
						    twentysixth twentyseventh twentyeighth twentynineth thirtyith thirtyfirst ]
    DAYS               = DAYS_NUM + DAYS_NUM_ALT + DAYS_WITH_SUFF

	YEARS_NUM          = (1900..2400).to_a
	YEARS_NUM_ALT      = %w[ 01 02 03 04 05 06 07 08 09] + (10..99).to_a
	YEARS              = YEARS_NUM #+ YEARS_NUM_ALT

	HOURS_NUM  	       = %w[1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 0]
	HOURS_NUM_ALT      = %w[01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 00]
	HOURS_WORDS        = %w[one two three four five six seven eight nine ten eleven twelve thirteen fourteen
						    fifteen sixteen seventeen eighteen nineteen twenty twentyone twentytwo twentythree oh]
	HOURS              = HOURS_NUM + 
						 HOURS_NUM_ALT + 
						 HOURS_WORDS

	MINUTES_NUM	       = %w[00 01 02 03 04 05 06 07 08 09] + (10..59).to_a
	MINUTES_WORD_10_59 =  %w[ten eleven twelve thirteen fourteen
						     fifteen sixteen seventeen eighteen nineteen twenty twentyone twentytwo twentythree twentyfour
						     twentyfive twentysix twentyseven twentyeight twentynine thirty thirtyone thirtytwo thirtythree
						     thirtyfour thirtyfive thirtysix thirtyseven thirtyeight thirtynine fourty fourtyone fourtytwo
					         fourtythree fourtyfour fourtyfive fourtysix fourtyseven fourtyeight fourtynine fifty fiftyone
					         fiftytwo fiftythree fiftyfour fiftyfive fiftysix fiftyseven fiftyeight fiftynine]
	MINUTES_WORD       = %w[zero one two three four five six seven eight nine] + 
						    MINUTES_WORD_10_59
	MINUTES_WORD_ALT   = %w[oclock ohone ohtwo ohthree ohfour ohfive ohsix ohseven oheight ohnine] +
						    MINUTES_WORD_10_59
	MINUTES_WORD_ALT2  = %w[o'clock one two three four five six seven eight nine] +
						    MINUTES_WORD_10_59
	MINUTES            = MINUTES_NUM +
					     MINUTES_WORD +
					     MINUTES_WORD_ALT +
					     MINUTES_WORD_ALT2

	TIME_NUM	       = /(#{HOURS.join('|')}):([0-5][0-9])[ ]?([pm|PM|p|P|am|AM|A|a]?)/
	TIME_SIMPLE        = /([0-2]?[0-9])[ ]?([pm|PM|p|P|am|AM|A|a]?)/
	TIME_PATTERN       = TIME_NUM
	SEPARATORS         = [" ","\/","\."]

	ANCHORS            = %w[this next last]
	MODIFIERS          = %w[]

	MONTH_DAY_YEAR_PATTERN = /
							  	(?<month>#{MONTHS.join('|')})
							  	(#{SEPARATORS.join('|')})
							  	(?<day>#{DAYS.join('|')})
							  	(#{SEPARATORS.join('|')})
							  	(?<year>#{YEARS.join('|')})
							 /ox
	DAY_MONTH_YEAR_PATTERN = /
							  	(?<day>#{DAYS.join('|')})
							  	(#{SEPARATORS.join('|')})
							  	(?<month>#{MONTHS.join('|')})		
							  	(#{SEPARATORS.join('|')})
							  	(?<year>#{YEARS.join('|')})	
							 /ox
	YEAR_MONTH_DAY_PATTERN = /
							  	(?<year>#{YEARS.join('|')})
							  	(#{SEPARATORS.join('|')})
							  	(?<month>#{MONTHS.join('|')})		
							  	(#{SEPARATORS.join('|')})
								(?<day>#{DAYS.join('|')})
							 /ox
	MONTH_DAY_PATTERN =      /
							  	(?<month>#{MONTHS.join('|')})		
							  	(#{SEPARATORS.join('|')})
								(?<day>#{DAYS.join('|')})
							 /ox

	def initialize(args="")
		if args.empty? then
			@date = Time.now
		else
			if match = args.match(MONTH_DAY_YEAR_PATTERN)
				puts "month day year pattern"
				self.parse_month_day_year match
			# elsif match = args.match(YEAR_MONTH_DAY_PATTERN)
			# 	puts "YEAR_MONTH_DAY_PATTERN"
			# 	self.parse_month_day_year match
			elsif match = args.match(DAY_MONTH_YEAR_PATTERN)
				puts "DAY_MONTH_YEAR_PATTERN"
				self.parse_month_day_year match
			elsif match = args.match(MONTH_DAY_PATTERN)
				puts "MONTH_DAY_PATTERN"
				self.parse_month_day_year match
			else
				@year   ||= Time.now.year
				@month  ||= Time.now.month
				@day    ||= Time.now.day
			end
			if match = args.match(TIME_PATTERN)
				self.parse_time(match)
			else
				@hour 	||= Time.now.hour
				@minute ||= Time.now.min
			end
		end


		@date = Time.new(@year, @month, @day, @hour, @minute)
	end

	def parse_month_day_year(match)
		if match.names.include?('year')
			self.year  = match['year']
		else
			self.year  = Time.now.year
		end
		if match.names.include?('month')
			@month = match['month']
		else
			@month = Time.now.month
		end
		if match.names.include?('day')
			@day   = match['day']
		else
			@day = Time.now.day
		end
	end

	def parse_time(match)
		self.hour = match[1]
		self.minute = match[2]
		unless match[3].empty?
			tod = match[3]
			if tod == 'p' then
				if @hour.to_i < 12
					@hour = (@hour.to_i + 12).to_s
				end
			end
		end
	end

	def hour=(h)
		if HOURS_NUM.include?(h)
			@hour = h
		elsif HOURS_NUM_ALT.include?(h)
			@hour = HOURS_NUM[HOURS_NUM_ALT.index(h)]
		elsif HOURS_WORDS.include?(h)
			@hour = HOURS_NUM[HOURS_WORDS.index(h)]
		else
			throw InvalidArgumentError
		end
	end

	def year=(y)
		if YEARS_NUM_ALT.include?(y) then
			@year = 2000 + y
		else
			@year = y
		end
	end

	def year
		@year
	end

end

